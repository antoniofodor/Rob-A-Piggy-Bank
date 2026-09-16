"""Validate the exported crate binary without Blender or third-party libraries."""
import json
import math
import struct
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / 'assets/crate'
raw = (OUT / 'AcornStorageCrate.glb').read_bytes()
magic, version, length = struct.unpack_from('<4sII', raw)
assert (magic, version, length) == (b'glTF', 2, len(raw))
jslength, kind = struct.unpack_from('<I4s', raw, 12)
assert kind == b'JSON'
doc = json.loads(raw[20:20+jslength])
offset = 20+jslength
binlength, kind = struct.unpack_from('<I4s', raw, offset)
assert kind == b'BIN\0' and offset+8+binlength == len(raw)
binary = raw[offset+8:]
assert len(doc['meshes']) == 4 and len(doc['nodes']) == 5
assert doc['nodes'][4] == {'name': 'AcornStorageCrate', 'children': [0, 1, 2, 3]}
assert doc['scenes'][0]['nodes'] == [4]
assert not doc.get('cameras') and not doc.get('animations')
assert len(doc['materials']) == len(doc['images']) == 1
for node in doc['nodes']:
    assert not any(key in node for key in ['translation', 'rotation', 'scale', 'matrix'])
for view in doc['bufferViews']:
    assert view['byteOffset'] % 4 == 0
    assert view['byteOffset']+view['byteLength'] <= doc['buffers'][0]['byteLength']

def values(index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
    fmt = {5126: 'f', 5125: 'I'}[a['componentType']]
    rows = list(struct.iter_unpack('<'+fmt*width,
                binary[view['byteOffset']:view['byteOffset']+view['byteLength']]))
    assert len(rows) == a['count']
    assert all(math.isfinite(x) for row in rows for x in row)
    return rows

all_positions = []
triangles = []
total = 0
for mesh in doc['meshes']:
    primitive, = mesh['primitives']
    assert primitive['mode'] == 4 and primitive['material'] == 0
    attr = primitive['attributes']
    pos, norm, uv = [values(attr[key]) for key in ['POSITION', 'NORMAL', 'TEXCOORD_0']]
    indices = [i[0] for i in values(primitive['indices'])]
    assert len(pos) == len(norm) == len(uv)
    assert len(indices) % 3 == 0
    assert all(0 <= i < len(pos) for i in indices)
    assert all(abs(sum(v*v for v in n)-1) < 1e-4 for n in norm)
    assert all(0 < u < 1 and 0 < v < 1 for u,v in uv)
    for i in range(0, len(indices), 3):
        a, b, c = [pos[j] for j in indices[i:i+3]]
        triangles.append((a, b, c))
        ab = [b[j]-a[j] for j in range(3)]
        ac = [c[j]-a[j] for j in range(3)]
        cross = (ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0])
        assert sum(cross[j]*norm[indices[i]][j] for j in range(3)) > 1e-9
        assert norm[indices[i]] == norm[indices[i+1]] == norm[indices[i+2]]
    all_positions.extend(pos)
    total += len(indices)//3
mins = [min(v[i] for v in all_positions) for i in range(3)]
maxs = [max(v[i] for v in all_positions) for i in range(3)]
assert total == 966 and total < 1000
assert all(abs(a-b) < 1e-5 for a,b in zip(mins, [-1.8, 0, -1.4]))
assert all(abs(a-b) < 1e-5 for a,b in zip(maxs, [1.8, 1.9, 1.4]))
# Vertical rays throughout the opening must meet only the floor, never a lid.
# glTF is Y-up, so barycentric projection uses X/Z.
for x in [-1.3, 0, 1.3]:
    for z in [-.95, 0, .95]:
        heights = set()
        for a, b, c in triangles:
            det = (b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
            if abs(det) < 1e-9:
                continue
            u = ((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2])) / det
            v = ((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2])) / det
            w = 1-u-v
            if min(u,v,w) >= -1e-6:
                heights.add(round(u*a[1]+v*b[1]+w*c[1], 5))
        assert heights == {0, .25}, (x, z, heights)
view = doc['bufferViews'][doc['images'][0]['bufferView']]
png = binary[view['byteOffset']:view['byteOffset']+view['byteLength']]
assert png == (OUT / 'AcornStorageCrate_Atlas.png').read_bytes()
assert struct.unpack_from('>II', png, 16) == (512, 512)
print('PASS: 966 triangles; exact dimensions; bottom-centre identity root; flat normals;')
print('valid winding/UVs/indices; one material; embedded 512x512 atlas; no presentation objects.')
print('PASS: nine interior probes confirm an open top and solid 0.25-unit floor.')
