"""Create a single-material-per-mesh Studio FBX from the v2 art source."""
import bpy,json
from pathlib import Path

out=Path(__file__).resolve().parents[3]/'assets/houses/treehouse-v2'
report=json.loads((out/'geometry-report.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(out/'treehouse.blend'))
for obj in list(bpy.context.scene.objects):
    if obj.type!='MESH' or obj.name.startswith('REVIEW'):
        bpy.data.objects.remove(obj,do_unlink=True)
for obj in list(bpy.context.scene.objects):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.separate(type='MATERIAL');bpy.ops.object.mode_set(mode='OBJECT')
meshes=list(bpy.context.scene.objects)
manifest=[]
for obj in meshes:
    used={p.material_index for p in obj.data.polygons}
    assert len(used)==1,(obj.name,used)
    material=obj.data.materials[next(iter(used))]
    for face in obj.data.polygons:face.material_index=0
    obj.data.materials.clear();obj.data.materials.append(material)
    obj.name=obj.get('section','Treehouse')+'_'+material.name
    node=material.node_tree.nodes.get('Principled BSDF')
    if node:node.inputs['Emission Strength'].default_value=0
    obj.hide_render=False
    manifest.append({'name':obj.name,'material':material.name,'colorRGB':report['paletteRGB'][material.name],'triangles':len(obj.data.polygons)})
assert sum(m['triangles'] for m in manifest)==report['triangles']
assert all(m['triangles']<20000 for m in manifest)
bpy.ops.object.select_all(action='SELECT')
path=out/'treehouse-roblox.fbx'
bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},axis_forward='Z',axis_up='Y',bake_anim=False,add_leaf_bones=False)
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(path));bpy.context.view_layer.update()
imported=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(imported)==len(manifest)
assert all(len(o.data.materials)==1 for o in imported)
vertices=[o.matrix_world@v.co for o in imported for v in o.data.vertices]
bounds={k:[fn(v[i] for v in vertices) for i in range(3)] for k,fn in [('min',min),('max',max)]}
error=max(abs(bounds[k][i]-report['boundsBlender'][k][i]) for k in ('min','max') for i in range(3))
assert error<.001,error
data={'export':'treehouse-roblox.fbx','meshCount':len(manifest),'triangles':report['triangles'],'singleMaterialPerMesh':True,'fbxRoundTripMaxBoundsError':error,'meshes':manifest,'studioImportScaleColorCollisionChecks':'pending','notes':'Visual export only. No collision guides, runtime scripts, lights or review ground. Apply manifest RGB values and SmoothPlastic if importer colours differ.'}
(out/'roblox-import-report.json').write_text(json.dumps(data,indent=2))
print(json.dumps({k:data[k] for k in ('export','meshCount','triangles','singleMaterialPerMesh','fbxRoundTripMaxBoundsError')}))
