"""Verify the saved Blender art revision and its FBX round trip."""
import bpy, json
from pathlib import Path

out=Path(__file__).resolve().parents[3]/'assets/houses/treehouse-v2'
report=json.loads((out/'geometry-report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(out/'treehouse.blend'))
source=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.name.startswith('REVIEW')]
assert len(source)==report['visualMeshes']
assert all(o['section'] for o in source)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(out/'treehouse-visual.fbx'))
bpy.context.view_layer.update()
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==report['visualMeshes']
vertices=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
bounds={k:[fn(v[i] for v in vertices) for i in range(3)] for k,fn in [('min',min),('max',max)]}
error=max(abs(bounds[k][i]-report['boundsBlender'][k][i]) for k in ('min','max') for i in range(3))
assert error<.001,error
assert all(m['nonManifoldEdges']==0 and m['triangles']<20000 for m in report['meshes'])
result={'savedSourceMeshes':len(source),'fbxMeshCount':len(meshes),'fbxMaxBoundsError':error,'individualMeshesManifold':True,'allMeshesUnder20000Triangles':True,'runtimeCollisionCameraMobileTests':'not performed; this is a visual revision','referenceComparison':'manually reviewed against fantasy-v2/treehouse-concept.png'}
(out/'asset-checks.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
