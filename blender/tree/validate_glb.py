"""Check the exported binary independently of Blender's mesh objects."""
import json
import math
import struct
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
folder=ROOT/'assets/tree/blender'
raw=(folder/'oak.glb').read_bytes()
magic,version,length=struct.unpack_from('<4sII',raw)
assert magic==b'glTF' and version==2 and length==len(raw)
json_length,json_type=struct.unpack_from('<I4s',raw,12)
assert json_type==b'JSON'
doc=json.loads(raw[20:20+json_length])
start=20+json_length
bin_length,bin_type=struct.unpack_from('<I4s',raw,start)
assert bin_type==b'BIN\0' and start+8+bin_length==len(raw)
binary=raw[start+8:]
assert len(doc['nodes'])==len(doc['meshes'])==2
assert {n['name'] for n in doc['nodes']}=={'Trunk','Canopy'}
assert len(doc['images'])==len(doc['materials'])==1
assert not doc.get('cameras') and not doc.get('animations')
for view in doc['bufferViews']:
 assert view['byteOffset']%4==0
 assert view['byteOffset']+view['byteLength']<=doc['buffers'][0]['byteLength']

def accessor(index):
 a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
 n={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']]
 fmt={5126:'f',5125:'I'}[a['componentType']]
 values=list(struct.iter_unpack('<'+fmt*n,binary[v['byteOffset']:v['byteOffset']+v['byteLength']]))
 assert len(values)==a['count']
 assert all(math.isfinite(x) for row in values for x in row)
 if 'min' in a:
  for i in range(n):
   assert abs(min(v[i] for v in values)-a['min'][i])<1e-5
   assert abs(max(v[i] for v in values)-a['max'][i])<1e-5
 return values

stats={}
for mesh in doc['meshes']:
 p,=mesh['primitives'];assert p['mode']==4 and p['material']==0
 pos=accessor(p['attributes']['POSITION']);norm=accessor(p['attributes']['NORMAL']);uv=accessor(p['attributes']['TEXCOORD_0']);indices=accessor(p['indices'])
 assert len(indices)%3==0 and len(indices)//3<10000
 assert len(pos)==len(norm)==len(uv)
 assert all(0<=i[0]<len(pos) for i in indices)
 assert all(abs(sum(x*x for x in n)-1)<1e-4 for n in norm)
 assert all(0<=u<=1 and 0<=v<=1 for u,v in uv)
 # Every foliage sample stays in a green tile; wood stays in brown tiles.
 for u,v in uv:
  tile=int(u*8)+int((1-v)*8)*8
  assert (8<=tile<=17) if mesh['name']=='Canopy' else (0<=tile<=7)
 for i in range(0,len(indices),3):
  a,b,c=[pos[indices[j][0]] for j in (i,i+1,i+2)]
  ab=[b[j]-a[j] for j in range(3)];ac=[c[j]-a[j] for j in range(3)]
  cross=(ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0])
  assert sum(cross[j]*norm[indices[i][0]][j] for j in range(3))>0,'inverted or degenerate triangle'
 bounds={'min':[min(v[i] for v in pos) for i in range(3)],'max':[max(v[i] for v in pos) for i in range(3)]}
 stats[mesh['name']]={'triangles':len(indices)//3,'bounds':bounds}
assert abs(stats['Trunk']['bounds']['min'][1])<1e-5
canopy=stats['Canopy']['bounds']
assert abs(canopy['max'][0]-canopy['min'][0]-8.5)<1e-5
assert 8.0<canopy['max'][1]<9.6
img=doc['images'][0];view=doc['bufferViews'][img['bufferView']]
png=binary[view['byteOffset']:view['byteOffset']+view['byteLength']]
assert png==(folder/'oak-basecolor.png').read_bytes()
assert png[:8]==b'\x89PNG\r\n\x1a\n'
assert struct.unpack_from('>II',png,16)==(256,256)
print('PASS: GLB header, accessors, counts, normals/winding, UV palette, embedded texture, names and compact dimensions.')
print(json.dumps(stats,indent=2))
