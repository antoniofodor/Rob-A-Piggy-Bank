"""Validate or upload the ten approved Arcade piggies with resumable receipts."""
import argparse
import hashlib
import json
import time
from pathlib import Path

import requests
import upload_images

ROOT = Path(__file__).resolve().parents[1]
SPECS = json.loads((ROOT/'assets/piggies/arcade-build-v1/manifest.json').read_text())['skins']
KEYS = [s['key'] for s in SPECS]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, data):
    pending = path.with_suffix('.json.writing')
    pending.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    pending.replace(path)


def inputs(key):
    spec = next(s for s in SPECS if s['key'] == key)
    folder = ROOT / 'assets/piggies' / spec['tier'] / key
    report = json.loads((folder/'package/arcade-v1-asset-report.json').read_text())
    assert report['baseGeometryAndUVPreserved'], key
    for part in report['parts']:
        assert part['triangles'] < 20000, part['name']
        if part['role'] == 'accessory':
            assert part['nonManifoldEdges'] == 0, part['name']
    assets = []
    for item in report['exports']:
        path = folder / 'package' / item['file']
        assert item['roundTripChecked'] and item['roundTripBoundsError'] < .001
        if 'accessories' in path.name:
            assets.append(('accessories', path, 'Model', 'model/fbx'))
    for item in report['textures']:
        path = folder / item['file']
        assert sha(path) == item['sha256'], path
        assets.append((item['role'], path, 'Image', 'image/png'))
    return folder, assets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--go', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    work = [(key, *inputs(key)) for key in KEYS]
    if not (args.go or args.check):
        for key, _, assets in work:
            print(key, ':', ', '.join(p.name for _, p, _, _ in assets))
        print('Validated 10 Arcade skins, 5 accessory models and 35 maps.')
        return
    session = requests.Session()
    session.headers['x-api-key'] = upload_images.read_key()
    # Same signed-in creator as the already uploaded coat maps; read it from
    # the existing authorized asset rather than depending on a typed user ID.
    reference = json.loads((ROOT/'assets/piggies/rare/glacier/manifest.json').read_text())
    aid = reference['templates']['body']['ids']['ColorMap']
    creator = upload_images.creator_id(session, [{'current_asset_id': aid}])
    assert str(creator) == '1403296598', 'Creator must match the game owner'
    for key, folder, assets in work:
        receipt = folder / 'roblox-uploads.json'
        data = json.loads(receipt.read_text()) if receipt.exists() else {
            'skin': key, 'revision': 'arcade-v1', 'creatorUserId': creator, 'assets': {}
        }
        for role, path, kind, mime in assets:
            item = data['assets'].get(role)
            if item:
                assert item['sha256'] == sha(path), f'{path} changed since upload receipt; review before reuploading'
            elif args.check:
                print(key, role, 'not uploaded', flush=True)
                continue
            else:
                request = dict(assetType=kind, displayName=path.stem,
                               description=f'Rob a Piggy Bank - {key} Arcade collection',
                               creationContext={'creator': {'userId': creator}})
                with path.open('rb') as file:
                    response = session.post(upload_images.API+'/assets',
                        files={'request': (None, json.dumps(request), 'application/json'),
                               'fileContent': (path.name, file, mime)}, timeout=120)
                response.raise_for_status()
                operation = response.json()
                operation_id = operation.get('operationId') or operation['path'].split('/')[-1]
                item = dict(source=path.relative_to(ROOT).as_posix(), sha256=sha(path),
                            assetType=kind, operationId=operation_id)
                data['assets'][role] = item
                save(receipt, data)
            if not item.get('assetId'):
                for _ in range(90):
                    response = session.get(upload_images.API+'/operations/'+item['operationId'], timeout=30)
                    response.raise_for_status()
                    operation = response.json()
                    if operation.get('done'):
                        if 'error' in operation:
                            item['error'] = operation['error']; save(receipt, data)
                            raise RuntimeError(f'{key}/{role}: {operation["error"]}')
                        result = operation['response']
                        item['assetId'] = str(result['assetId'])
                        item['moderationState'] = result.get('moderationResult', {}).get('moderationState')
                        save(receipt, data)
                        break
                    time.sleep(2)
                else:
                    raise TimeoutError(f'{key}/{role} still processing; rerun to resume recorded operation')
            if args.check:
                response = session.get(upload_images.API+'/assets/'+item['assetId'], timeout=30)
                response.raise_for_status()
                item['moderationState'] = response.json().get('moderationResult', {}).get('moderationState')
                save(receipt, data)
            print(key, role, item['assetId'], item.get('moderationState'), flush=True)


if __name__ == '__main__':
    main()
