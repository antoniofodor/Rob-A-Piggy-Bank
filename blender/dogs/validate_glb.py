"""Validate exported dog geometry without Blender or third-party libraries."""
import json
import math
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def validate(path):
    raw=path.read_bytes()
    magic,version,length=struct.unpack_from('<4sII',raw)
    assert magic==b'glTF' and version==2 and length==len(raw)
    jl,jt=struct.unpack_from('<I4s',raw,12)
    assert jt==b'JSON'
    doc=json.loads(raw[20:20+jl])
    bl,bt=struct.unpack_from('<I4s',raw,20+jl)
    assert bt==b'BIN\0'
    binary=raw[28+jl:]
    assert len(binary)==bl and doc['buffers'][0]['byteLength']<=bl
    report=json.loads(path.with_name(path.stem+'-report.json').read_text())

    def accessor(i):
        a=doc['accessors'][i];v=doc['bufferViews'][a['bufferView']]
        n={'VEC3':3,'SCALAR':1}[a['type']]
        fmt={5126:'f',5125:'I'}[a['componentType']]
        assert a['count']*n*4==v['byteLength']
        start=v.get('byteOffset',0)
        assert start%4==0 and start+v['byteLength']<=bl
        vals=list(struct.iter_unpack('<'+fmt*n,binary[start:start+v['byteLength']]))
        assert all(math.isfinite(x) for row in vals for x in row)
        if 'min' in a:
            for axis in range(n):
                assert abs(min(v[axis] for v in vals)-a['min'][axis])<1e-5
                assert abs(max(v[axis] for v in vals)-a['max'][axis])<1e-5
        return vals

    names=set();total=0;groups=set();tones=set();bounds=[]
    for node in doc['nodes']:
        assert node['name'] not in names
        names.add(node['name'])
        groups.add(node['extras']['group']);tones.add(node['extras']['tone'])
        assert len(node['translation'])==3
        mesh=doc['meshes'][node['mesh']]
        assert len(mesh['primitives'])==1
        p=mesh['primitives'][0]
        pos=accessor(p['attributes']['POSITION'])
        norm=accessor(p['attributes']['NORMAL'])
        indices=[r[0] for r in accessor(p['indices'])]
        assert len(indices)%3==0 and len(pos)==len(norm)
        count=len(indices)//3
        assert 0<count<10000
        assert count==report['parts'][node['name']]['triangles']
        assert all(0<=i<len(pos) for i in indices)
        for n in norm:assert abs(sum(x*x for x in n)-1)<1e-4
        for i in range(0,len(indices),3):
            a,b,c=(pos[j] for j in indices[i:i+3])
            u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
            cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            assert sum(x*x for x in cross)>1e-16,(node['name'],'degenerate triangle')
            assert sum(cross[j]*norm[indices[i]][j] for j in range(3))>0,(node['name'],'inverted normal')
        for v in pos:bounds.append([v[j]+node['translation'][j] for j in range(3)])
        mat=doc['materials'][p['material']]
        assert len(mat['pbrMetallicRoughness']['baseColorFactor'])==4
        total+=count
    assert total==report['triangles']
    assert {'body','head','ear','leg','paw','tail'}<=groups
    assert {'fur','dark','eye','collar'}<=tones
    assert {'Body','Head','Muzzle','Collar','Tail','FrontLeg_L','FrontLeg_R','HindLeg_L','HindLeg_R'}<=names
    assert not doc.get('images') and not doc.get('textures')
    for axis in range(3):
        extent=max(v[axis] for v in bounds)-min(v[axis] for v in bounds)
        assert abs(extent-report['sizeRoblox'][axis])<1e-4
    print(f'PASS {path.stem}: {len(names)} independent parts, {total:,} triangles; bounds, pivots, normals, winding, material slots.')


if __name__=='__main__':
    files=list((ROOT/'assets/dogs').glob('*/*.glb'))
    assert len(files)==3,'Expected all three breeds'
    for path in sorted(files):validate(path)
