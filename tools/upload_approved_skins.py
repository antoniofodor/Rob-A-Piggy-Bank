"""Resumable uploader for the eight approved revisions; preserve older receipts."""
import hashlib,json
from pathlib import Path
import upload_spectral as uploader
from approved_skin_batch import ROOT,HERE,SPECS,report

HERE.mkdir(parents=True,exist_ok=True)
uploader.KEYS=[s['key'] for s in SPECS]
known={}
for path in (ROOT/'assets/piggies').rglob('*uploads.json'):
    try:
        for item in json.loads(path.read_text()).get('assets',{}).values():
            if item.get('assetId') and item.get('moderationState')=='Approved':known[item['sha256']]=item
    except (ValueError,KeyError):pass

def inputs(key):
    spec=next(s for s in SPECS if s['key']==key);r=report(spec)
    assert r['baseGeometryAndUVPreserved']
    for p in r['parts']:assert p['triangles']<20000 and p['nonManifoldEdges']==0,(key,p['name'])
    assets=[]
    for i,t in enumerate(r['textures']):
        path=spec['home']/t['file'];assert uploader.sha(path)==t['sha256'],path
        role=t['role']
        if role=='shoulder_color':role=path.stem
        assets.append((role,path,'Image','image/png'))
    for e in r['exports']:
        if 'accessories' not in e['file']:continue
        path=spec['package']/e['file'];assert e['roundTripChecked'] and e['roundTripBoundsError']<.001
        if e.get('sha256'):assert uploader.sha(path)==e['sha256']
        assets.append(('accessories',path,'Model','model/fbx'))
    folder=HERE/key;folder.mkdir(exist_ok=True)
    target=folder/'roblox-uploads.json'
    data=json.loads(target.read_text()) if target.exists() else dict(skin=key,revision=spec['revision'],creatorUserId='1403296598',assets={})
    for role,path,kind,mime in assets:
        digest=uploader.sha(path)
        if role not in data['assets'] and digest in known:
            item=known[digest].copy();item['source']=path.relative_to(ROOT).as_posix();item['reusedByHash']=True
            data['assets'][role]=item
    uploader.save(target,data)
    return folder,assets

uploader.inputs=inputs
if __name__=='__main__':uploader.main()
