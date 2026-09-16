"""Minimal glTF 2.0 exporter for these two static, UV-textured meshes.
Avoids this Blender installation's incompatible bundled NumPy binary.
GLB uses flat per-face normals, one embedded base-colour texture, Y-up units.
"""
import json
import struct
from pathlib import Path


def export_glb(objects, texture_path, output):
    data=bytearray()
    doc={'asset':{'version':'2.0','generator':'Blender oak static mesh exporter'},
         'scene':0,'scenes':[{'nodes':list(range(len(objects)))}],
         'nodes':[],'meshes':[],'bufferViews':[],'accessors':[],
         'materials':[{'name':'Oak_BaseColor','pbrMetallicRoughness':{
             'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.87}}],
         'textures':[{'source':0,'sampler':0}],
         'samplers':[{'magFilter':9728,'minFilter':9728,'wrapS':33071,'wrapT':33071}]}
    def view(blob,target=None):
        while len(data)%4:data.append(0)
        offset=len(data);data.extend(blob)
        v={'buffer':0,'byteOffset':offset,'byteLength':len(blob)}
        if target:v['target']=target
        doc['bufferViews'].append(v);return len(doc['bufferViews'])-1
    def accessor(values,kind,components,integer=False,bounds=False):
        flat=[v for row in values for v in row]
        buf=struct.pack('<'+('I' if integer else 'f')*len(flat),*flat)
        a={'bufferView':view(buf,34963 if integer else 34962),'componentType':5125 if integer else 5126,
           'count':len(values),'type':kind}
        if bounds:
            a['min']=[min(v[i] for v in values) for i in range(components)]
            a['max']=[max(v[i] for v in values) for i in range(components)]
        doc['accessors'].append(a);return len(doc['accessors'])-1
    for i,obj in enumerate(objects):
        mesh=obj.data;mesh.calc_loop_triangles()
        positions=[];normals=[];uvs=[];indices=[]
        for tri in mesh.loop_triangles:
            normal=mesh.polygons[tri.polygon_index].normal
            for loop_index in tri.loops:
                co=mesh.vertices[mesh.loops[loop_index].vertex_index].co
                uv=mesh.uv_layers.active.data[loop_index].uv
                positions.append((co.x,co.z,-co.y))
                normals.append((normal.x,normal.z,-normal.y))
                uvs.append((uv.x,1-uv.y));indices.append((len(indices),))
        attrs={'POSITION':accessor(positions,'VEC3',3,bounds=True),
               'NORMAL':accessor(normals,'VEC3',3),'TEXCOORD_0':accessor(uvs,'VEC2',2)}
        index=accessor(indices,'SCALAR',1,integer=True)
        doc['meshes'].append({'name':obj.name,'primitives':[{'attributes':attrs,'indices':index,'material':0,'mode':4}]})
        doc['nodes'].append({'name':obj.name,'mesh':i})
    image_view=view(Path(texture_path).read_bytes())
    doc['images']=[{'bufferView':image_view,'mimeType':'image/png','name':'Oak_BaseColor'}]
    doc['buffers']=[{'byteLength':len(data)}]
    raw=json.dumps(doc,separators=(',',':')).encode()
    raw+=b' '*((-len(raw))%4);data.extend(b'\0'*((-len(data))%4))
    out=struct.pack('<4sII',b'glTF',2,12+8+len(raw)+8+len(data))
    out+=struct.pack('<I4s',len(raw),b'JSON')+raw
    out+=struct.pack('<I4s',len(data),b'BIN\0')+data
    Path(output).write_bytes(out)
