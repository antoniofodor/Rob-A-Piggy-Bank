"""Upload the approved epic revisions, excluding Lion, with resumable receipts.

Default is a local validation/dry run. --go sends the three accessory FBXs
and six body/trim maps. Palettes are embedded in the FBXs. --check refreshes
moderation status. Each operation is recorded before polling to avoid duplicate
uploads after an interrupted run. User upload authorization is required.
"""
import argparse
import hashlib
import json
import time
from pathlib import Path

import requests
import upload_images

ROOT = Path(__file__).resolve().parents[1]
KEYS = ('hedgehog', 'stormstone', 'peacock')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, data):
    pending = path.with_suffix('.json.writing')
    pending.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    pending.replace(path)


def inputs(key):
    folder = ROOT / 'assets/piggies/epic' / key
    report = json.loads((folder / 'package/epic-v2/asset-report.json').read_text())
    assert report['baseGeometryUnchanged'] and report['baseUVsPreserved'], key
    for part in report['parts']:
        assert part['triangles'] < 20000, part['name']
        if part['role'] == 'accessory':
            assert part['nonManifoldEdges'] == 0, part['name']
    for item in report['exports']:
        assert sha(folder / 'package/epic-v2' / item['file']) == item['sha256']
        assert item['roundTripBoundsError'] < .001
    return folder, [
        ('accessories', folder / 'package/epic-v2' / f'{key}-epic-v2-accessories.fbx', 'Model', 'model/fbx'),
        ('body', folder / 'sheets' / f'{key}-epic-v2-body.png', 'Image', 'image/png'),
        ('trim', folder / 'sheets' / f'{key}-epic-v2-trim.png', 'Image', 'image/png'),
    ]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--go', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    work = [(key, *inputs(key)) for key in KEYS]
    if not (args.go or args.check):
        for key, _, assets in work:
            print(key, ':', ', '.join(p.name for _, p, _, _ in assets))
        print('Validated 3 skins; 3 accessory models and 6 coat maps. Lion excluded.')
        return
    session = requests.Session()
    session.headers['x-api-key'] = upload_images.read_key()
    # Same signed-in creator as the already uploaded coat maps; read it from
    # the existing authorized asset rather than depending on a typed user ID.
    reference = json.loads((ROOT/'assets/piggies/rare/glacier/manifest.json').read_text())
    aid = reference['templates']['body']['ids']['ColorMap']
    creator = upload_images.creator_id(session, [{'current_asset_id': aid}])
    for key, folder, assets in work:
        receipt = folder / 'roblox-uploads.json'
        data = json.loads(receipt.read_text()) if receipt.exists() else {
            'skin': key, 'revision': 'epic-v2', 'creatorUserId': creator, 'assets': {}
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
                               description=f'Rob a Piggy Bank - {key} epic revision',
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
