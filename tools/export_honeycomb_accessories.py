import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/piggies/rare/honeycomb/revisions/hexagonal-installed'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/piggies/rare/honeycomb/package/honeycomb-complete.blend'))
bpy.ops.object.select_all(action='DESELECT')
for name in ('Snout','Ears','Legs'):bpy.data.objects[name].select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Snout']
bpy.ops.object.join();trim=bpy.context.object;trim.name='HoneyTrim'
bpy.ops.object.select_all(action='DESELECT')
names=('HoneyTrim','Tail','HoneyDrop','HoneyDropHighlight')
for name in names:bpy.data.objects[name].select_set(True)
bpy.ops.export_scene.fbx(filepath=str(OUT/'honeycomb-accessories.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',path_mode='COPY',embed_textures=True,bake_anim=False,use_triangles=True)
out={}
for name in names:
 o=bpy.data.objects[name];v=[o.matrix_world@p.co for p in o.data.vertices]
 low=[min(p[i] for p in v) for i in range(3)];high=[max(p[i] for p in v) for i in range(3)]
 center=[(a+b)/2 for a,b in zip(low,high)];size=[b-a for a,b in zip(low,high)]
 out[name]={'center':[-center[0],center[2],center[1]],'size':[size[0],size[2],size[1]],'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)}
 assert out[name]['triangles']<20000
(OUT/'accessories-report.json').write_text(json.dumps(out,indent=2))
