"""Round-trip the FBX and record export integrity; does not alter the source."""
from pathlib import Path
import json
import bpy
import bmesh

out = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(out / 'lasso-rope.fbx'))
objects = list(bpy.context.scene.objects)
assert sorted(o.name for o in objects) == ['Grip', 'Rope']
checks = []
for obj in objects:
    assert obj.type == 'MESH'
    obj.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    assert all(edge.is_manifold for edge in bm.edges)
    bm.free()
    assert len(obj.data.materials) == 1
    assert all(n.type != 'TEX_IMAGE' for n in obj.data.materials[0].node_tree.nodes)
    assert all(not p.use_smooth for p in obj.data.polygons)
    checks.append({'name': obj.name, 'triangles': len(obj.data.loop_triangles),
        'closed_manifold': True, 'flat_shaded': True, 'texture_images': 0})
assert sum(c['triangles'] for c in checks) == 4964
(out / 'export-check.json').write_text(json.dumps({'fbx_round_trip': 'passed', 'parts': checks}, indent=2) + '\n')
print('FBX round-trip passed:', checks)
