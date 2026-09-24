"""Upload the reviewed meadow and border FBXs, resuming recorded operations.
Default validates only. --go uploads; --check refreshes moderation status.
"""
import argparse, hashlib, json, time
from pathlib import Path
import requests
import upload_images

ROOT=Path(__file__).resolve().parents[1]
FOLDER=ROOT/'assets/environment/piggy-meadows/build-v1'
def save(path,data):
    pending=path.with_suffix('.writing');pending.write_text(json.dumps(data,indent=2)+'\n');pending.replace(path)
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--go',action='store_true');parser.add_argument('--check',action='store_true');args=parser.parse_args()
    catalog=json.loads((FOLDER/'catalog.json').read_text())
    packages=[name for name in ('meadow','border','shore') if name in catalog]
    for name in packages:
        assert hashlib.sha256((FOLDER/catalog[name]['file']).read_bytes()).hexdigest()==catalog[name]['sha256']
    assert all(0<p['triangles']<20000 for p in catalog['parts'].values())
    if not(args.go or args.check):
        print('Validated',len(catalog['parts']),'meshes;',len(packages),'FBX packages, each with one embedded palette.');return
    session=requests.Session();session.headers['x-api-key']=upload_images.read_key()
    reference=json.loads((ROOT/'assets/piggies/rare/glacier/manifest.json').read_text())
    creator=upload_images.creator_id(session,[{'current_asset_id':reference['templates']['body']['ids']['ColorMap']}])
    receipt=FOLDER/'roblox-uploads.json';data=json.loads(receipt.read_text()) if receipt.exists() else {'creatorUserId':creator,'assets':{}}
    for name in packages:
        source=catalog[name];item=data['assets'].get(name)
        if item:assert item['sha256']==source['sha256'],'Source changed after upload; review revision first'
        elif args.check:continue
        else:
            request={'assetType':'Model','displayName':'Piggy Meadows '+name+' v1','description':'Low-poly environment for Rob A Piggy Bank','creationContext':{'creator':{'userId':creator}}}
            with (FOLDER/source['file']).open('rb') as f:
                result=session.post(upload_images.API+'/assets',files={'request':(None,json.dumps(request),'application/json'),'fileContent':(source['file'],f,'model/fbx')},timeout=120)
            result.raise_for_status();op=result.json();item={'file':source['file'],'sha256':source['sha256'],'operationId':op.get('operationId') or op['path'].split('/')[-1]};data['assets'][name]=item;save(receipt,data)
        if not item.get('assetId'):
            for _ in range(90):
                result=session.get(upload_images.API+'/operations/'+item['operationId'],timeout=30);result.raise_for_status();op=result.json()
                if op.get('done'):
                    if 'error' in op:raise RuntimeError(op['error'])
                    item['assetId']=str(op['response']['assetId']);item['moderationState']=op['response'].get('moderationResult',{}).get('moderationState');save(receipt,data);break
                time.sleep(2)
            else:raise TimeoutError('Operation pending; rerun to resume')
        if args.check:
            result=session.get(upload_images.API+'/assets/'+item['assetId'],timeout=30);result.raise_for_status();item['moderationState']=result.json().get('moderationResult',{}).get('moderationState');save(receipt,data)
        print(name,item['assetId'],item.get('moderationState'),flush=True)
if __name__=='__main__':main()
