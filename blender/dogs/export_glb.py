"""Small static, untextured GLB exporter; no NumPy or Blender add-on dependency.

Each named Blender object remains a separate node with its joint origin.
Flat normals and one tintable material per mesh preserve the game's coat slots.
"""
import json
import struct
from pathlib import Path


def export_glb(objects, path):
    blob = bytearray()
    doc = dict(asset={'version': '2.0', 'generator': 'Blender guard dog authoring'},
               scene=0, scenes=[{'nodes': list(range(len(objects)))}], nodes=[],
               meshes=[], materials=[], bufferViews=[], accessors=[])
    materials = {}

    def accessor(rows, kind, indices=False):
        while len(blob) % 4:
            blob.append(0)
        start = len(blob)
        flat = [x for row in rows for x in row]
        blob.extend(struct.pack('<' + ('I' if indices else 'f') * len(flat), *flat))
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': start,
                                  'byteLength': len(blob)-start,
                                  'target': 34963 if indices else 34962})
        entry = {'bufferView': len(doc['bufferViews'])-1,
                 'componentType': 5125 if indices else 5126,
                 'count': len(rows), 'type': kind}
        if kind == 'VEC3':
            entry['min'] = [min(r[i] for r in rows) for i in range(3)]
            entry['max'] = [max(r[i] for r in rows) for i in range(3)]
        doc['accessors'].append(entry)
        return len(doc['accessors'])-1

    for obj in objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        mat = mesh.materials[0]
        if mat.name not in materials:
            materials[mat.name] = len(doc['materials'])
            doc['materials'].append({'name': mat.name, 'pbrMetallicRoughness': {
                'baseColorFactor': list(mat.diffuse_color),
                'metallicFactor': 0, 'roughnessFactor': .82}})
        pivot = obj.matrix_world.translation
        nmat = obj.matrix_world.to_3x3().inverted().transposed()
        positions, normals, idx = [], [], []
        for tri in mesh.loop_triangles:
            normal = (nmat @ mesh.polygons[tri.polygon_index].normal).normalized()
            for vi in tri.vertices:
                co = obj.matrix_world @ mesh.vertices[vi].co - pivot
                positions.append((co.x, co.z, -co.y))
                normals.append((normal.x, normal.z, -normal.y))
                idx.append((len(idx),))
        attrs = {'POSITION': accessor(positions, 'VEC3'),
                 'NORMAL': accessor(normals, 'VEC3')}
        primitive = {'attributes': attrs, 'indices': accessor(idx, 'SCALAR', True),
                     'material': materials[mat.name], 'mode': 4}
        doc['meshes'].append({'name': obj.name, 'primitives': [primitive]})
        doc['nodes'].append({'name': obj.name, 'mesh': len(doc['meshes'])-1,
                             'translation': [pivot.x, pivot.z, -pivot.y],
                             'extras': {'tone': obj['tone'], 'group': obj['group']}})
    doc['buffers'] = [{'byteLength': len(blob)}]
    raw = json.dumps(doc, separators=(',', ':')).encode()
    raw += b' ' * (-len(raw) % 4)
    blob.extend(b'\0' * (-len(blob) % 4))
    out = struct.pack('<4sII', b'glTF', 2, 28 + len(raw) + len(blob))
    out += struct.pack('<I4s', len(raw), b'JSON') + raw
    out += struct.pack('<I4s', len(blob), b'BIN\0') + blob
    Path(path).write_bytes(out)
