"""Upload the approved closed-back Storm Wolf once, with a resumable receipt."""
import argparse,hashlib,json,time
from pathlib import Path
import requests
import upload_images

ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'assets/piggies/legendary/stormwolf'
PACKAGE=FOLDER/'package'
RECEIPT=FOLDER/'closed-back-roblox-upload.json'

def save(data):
    pending=RECEIPT.with_suffix('.writing')
    pending.write_text(json.dumps(data,indent=2),encoding='utf-8')
    pending.replace(RECEIPT)

def main():
    args=argparse.ArgumentParser();args.add_argument('--go',action='store_true');args=args.parse_args()
    path=PACKAGE/'stormwolf-complete.fbx'
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest==hashlib.sha256((PACKAGE/'stormwolf-tail-seated.fbx').read_bytes()).hexdigest()
    report=json.loads((PACKAGE/'stormwolf-layout-checks.json').read_text(encoding='utf-8'))
    assert report['closedBack'] and not report['closedBackRayMisses']
    assert report['fbxRoundTripBoundsError']<1e-4
    assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in report['meshes'])
    if not args.go:
        print('Validated approved Storm Wolf model:',digest);return
    session=requests.Session();session.headers['x-api-key']=upload_images.read_key()
    if RECEIPT.exists():
        data=json.loads(RECEIPT.read_text(encoding='utf-8'))
        assert data['sha256']==digest,'Model changed since receipt; do not upload twice'
        assert data.get('operationId') or data.get('assetId'),'Uncertain upload: inspect before resending'
    else:
        creator=upload_images.creator_id(session,[{'current_asset_id':'rbxassetid://123936560500286'}])
        data={'source':path.relative_to(ROOT).as_posix(),'sha256':digest,'creatorUserId':creator,'state':'submitting'}
        save(data)
        request={'assetType':'Model','displayName':'Storm Wolf repaired back and tail',
                 'description':'Rob a Piggy Bank approved Storm Wolf mesh repair',
                 'creationContext':{'creator':{'userId':creator}}}
        with path.open('rb') as f:
            response=session.post(upload_images.API+'/assets',files={
                'request':(None,json.dumps(request),'application/json'),
                'fileContent':(path.name,f,'model/fbx')},timeout=120)
        response.raise_for_status();operation=response.json()
        data.update(operationId=operation.get('operationId') or operation['path'].split('/')[-1],state='processing');save(data)
    if not data.get('assetId'):
        for _ in range(90):
            response=session.get(upload_images.API+'/operations/'+data['operationId'],timeout=30)
            response.raise_for_status();operation=response.json()
            if operation.get('done'):
                if operation.get('error'):
                    data.update(error=operation['error'],state='failed');save(data);raise RuntimeError(operation['error'])
                result=operation['response'];data.update(assetId=str(result['assetId']),state='uploaded',moderationState=result.get('moderationResult',{}).get('moderationState'));save(data);break
            time.sleep(2)
        else:raise TimeoutError('Processing: rerun to resume this operation')
    print(json.dumps(data),flush=True)

if __name__=='__main__':main()
