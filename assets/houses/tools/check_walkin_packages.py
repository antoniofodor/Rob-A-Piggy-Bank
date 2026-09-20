"""Check final-size geometry, import manifests, collision and door contracts."""
import json,math
from pathlib import Path
from walkin_catalogue import SPECS,AUTHOR_SCALE,folder
BASE=Path(__file__).resolve().parents[1]
def check(slug):
    rev=SPECS[slug][0]+1;out=BASE/folder(slug,rev)
    geo=json.loads((out/'geometry-report.json').read_text())
    imp=json.loads((out/'roblox-import-report.json').read_text())
    walk=geo['walkIn'];x0,x1,y0,y1,f,c=walk['roomBounds']
    assert walk['bakedExteriorScale']==AUTHOR_SCALE[slug] and walk['runtimeDisplayScale']==1
    assert x1-x0>=12.3 and c-f>=8 and walk['entry'][4]>=7
    assert not walk['blocked'] and walk['probes']>=40
    assert geo['collisionBoxesDraft'] and 'Wall' in geo['mountsBlender']
    assert geo['mountYawBlender']['Wall']==180
    assert any('side' in b['name'].lower() for b in geo['collisionBoxesDraft'])
    assert any('floor' in b['name'].lower() or 'deck' in b['name'].lower() for b in geo['collisionBoxesDraft'])
    assert imp['singleMaterialPerMesh'] and imp['fbxRoundTripMaxBoundsError']<.001
    assert imp['triangles']==geo['triangles'] and all(m['triangles']<20000 for m in imp['meshes'])
    assert all(m['nonManifoldEdges']==0 for m in geo['meshes'])
    assert len(walk['doors'])==2
    for door in walk['doors']:
        assert any(m['name'].startswith(door['name']+'_') for m in imp['meshes']),door
    if slug=='modern':
        glass=[m for m in imp['meshes'] if m['material']=='DomeGlass']
        assert glass and all(m['roblox']['RobloxTransparency']==.82 for m in glass)
    # Independent collision checks over the middle of the room and its entry.
    # An oriented box is tested in its own frame, not with inflated world AABBs.
    def local(box,x,y):
        cx,cy,cz=box['blenderLocation'];angle=box.get('rotationZ',0)
        co,si=math.cos(angle),math.sin(angle)
        return co*(x-cx)+si*(y-cy),-si*(x-cx)+co*(y-cy),cz
    points=[((x0+x1)/2,(y0+y1)/2,f),(walk['entry'][0],y0+.6,f)]
    for x,y,z in points:
        supporting=[]
        for b in geo['collisionBoxesDraft']:
            lx,ly,cz=local(b,x,y);sx,sy,sz=b['sizeXYZ']
            if abs(lx)<sx/2 and abs(ly)<sy/2 and abs(cz+sz/2-z)<.3:supporting.append(b)
            if abs(lx)<sx/2+.75 and abs(ly)<sy/2+.75:
                assert not (cz+sz/2>z+.35 and cz-sz/2<z+5.7),(slug,'collider blocks body',b['name'],x,y)
        assert supporting,(slug,'unsupported floor',x,y)
    return {'id':slug,'revision':rev,'meshes':imp['meshCount'],'triangles':imp['triangles'],'clearanceSamples':walk['probes'],'bakedScale':AUTHOR_SCALE[slug]}
if __name__=='__main__':
    rows=[check(slug) for slug in SPECS]
    (BASE/'walk-in-review/package-checks.json').write_text(json.dumps({'passed':True,'houses':rows,'liveStudioChecks':'pending fresh mesh imports'},indent=2))
    print(f'PASS: {len(rows)} walk-in packages, {sum(r["clearanceSamples"] for r in rows)} geometry probes, matching collision/door/material contracts.')
