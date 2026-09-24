"""Check the saved Blender sources and round-trip every production FBX."""
from pathlib import Path
import json
import math
import hashlib
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SETS = [('coil','coil'),('loop','loop'),('snapped-end','snapped-end'),('daze-star','daze-star')]

def bounds(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    return [[min(v[k] for v in points) for k in range(3)],
            [max(v[k] for v in points) for k in range(3)]]

def inspect(obj,textured):
    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    assert all(e.is_manifold for e in bm.edges), obj.name
    assert bm.calc_volume(signed=True) > 0, obj.name
    bm.free()
    assert all(not p.use_smooth for p in mesh.polygons), obj.name
    assert all(t.area > 1e-12 for t in mesh.loop_triangles), obj.name
    assert len(mesh.materials) == 1, obj.name
    if textured:
        assert len(mesh.uv_layers) == 1, obj.name
        assert all(math.isfinite(float(c)) for uv in mesh.uv_layers.active.data for c in uv.uv)
        nodes = [n for n in mesh.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE']
        assert len(nodes) == 1 and nodes[0].image, obj.name
        assert tuple(nodes[0].image.size) == (1024,1024), obj.name
    return {'triangles':len(mesh.loop_triangles),'bounds':bounds(obj),
            'closed_manifold':True,'flat_shaded':True,'uv_valid':bool(textured)}

results = {}
for key,base in SETS:
    report = json.loads((ROOT/key/'manifest.json').read_text())
    textured = key != 'daze-star'
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/key/(base+'.blend')))
    source = {o.name:inspect(o,textured) for o in bpy.context.scene.objects if o.type == 'MESH'}
    assert set(source) == {x['name'] for x in report['parts']}
    assert sum(x['triangles'] for x in source.values()) <= report['triangle_budget']
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(ROOT/key/(base+'.fbx')))
    objects = list(bpy.context.scene.objects)
    assert all(o.type == 'MESH' for o in objects)
    imported = {o.name:inspect(o,textured) for o in objects}
    assert set(source) == set(imported)
    for name in source:
        assert source[name]['triangles'] == imported[name]['triangles']
        for a,b in zip(sum(source[name]['bounds'],[]),sum(imported[name]['bounds'],[])):
            assert abs(a-b) < .0001,(key,name,a,b)
    results[key] = {'source':'passed','fbx_round_trip':'passed','parts':imported}
    for part in report['parts']:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(ROOT/key/'parts'/(part['name'].lower()+'.fbx')))
        objs = list(bpy.context.scene.objects)
        assert len(objs) == 1 and objs[0].name == part['name']
        got = inspect(objs[0],textured)
        assert got['triangles'] == source[part['name']]['triangles']
        for a,b in zip(sum(got['bounds'],[]),sum(source[part['name']]['bounds'],[])):
            assert abs(a-b) < .0001
    results[key]['per_part_exports'] = 'passed; placement preserved'

hashes = {}
for tier in ['rope','braided','golden','elite']:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'tiers'/(tier+'.blend')))
    rows = []
    for o in sorted((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:o.name):
        inspect(o,True)
        rows.append([o.name,[[round(float(c),6) for c in v.co] for v in o.data.vertices],
                     [list(p.vertices) for p in o.data.polygons],
                     [[round(float(c),6) for c in uv.uv] for uv in o.data.uv_layers.active.data]])
    hashes[tier] = hashlib.sha256(json.dumps(rows).encode()).hexdigest()
assert len(set(hashes.values())) == 1,hashes
results['tier_geometry_and_uvs'] = {'identical':True,'sha256':hashes}
results['limitations'] = ['Not uploaded; no live in-hand or catch-animation fit test.']
(ROOT/'validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('VALIDATION_PASSED '+json.dumps({k:v.get('fbx_round_trip') for k,v in results.items() if isinstance(v,dict)}))
