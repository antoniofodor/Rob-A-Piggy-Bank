"""Export the repaired body separately so only one Roblox mesh needs replacing."""
from pathlib import Path
import bpy,bmesh,json,hashlib

folder=Path(__file__).resolve().parents[1]/'package'
bpy.ops.wm.open_mainfile(filepath=str(folder/'stormwolf-complete.blend'))
body=bpy.data.objects['Body']
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True);bpy.context.view_layer.objects.active=body
vertices=[body.matrix_world@v.co for v in body.data.vertices]
lo=[min(v[i] for v in vertices) for i in range(3)]
hi=[max(v[i] for v in vertices) for i in range(3)]
center=[(a+b)/2 for a,b in zip(lo,hi)];size=[b-a for a,b in zip(lo,hi)]
bm=bmesh.new();bm.from_mesh(body.data)
bad=sum(not e.is_manifold for e in bm.edges);bm.free();assert bad==0
tris=sum(len(p.vertices)-2 for p in body.data.polygons)
assert tris<20000 and body.data.uv_layers
path=folder/'stormwolf-body-closed.fbx'
bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},
    axis_forward='-Z',axis_up='Y',add_leaf_bones=False,bake_anim=False,
    path_mode='COPY',embed_textures=True,use_triangles=True)
known=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(path),use_anim=False)
imported=[o for o in bpy.data.objects if o not in known and o.type=='MESH']
assert len(imported)==1
ob=imported[0]
assert sum(len(p.vertices)-2 for p in ob.data.polygons)==tris and ob.data.uv_layers
coords=[ob.matrix_world@v.co for v in ob.data.vertices]
error=max(abs(fn(v[i] for v in coords)-bound[i]) for fn,bound in ((min,lo),(max,hi)) for i in range(3))
assert error<1e-4
report={'closedBack':True,'triangles':tris,'nonManifoldEdges':bad,'fbxBoundsError':error,
        'bodyFbxSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'sizeStuds':[size[0],size[2],size[1]],
        'configOffsetStuds':[center[0],6.62+center[2],-center[1]],
        'integration':'This file repairs Body only. For the relocated tail use the complete FBX and replace Body, Tail, Lightning_p4 and Lightning_p5 IDs and imported bounds. Keep the existing legend_stormwolf maps and runtime scale.'}
(folder/'closed-back-checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('STORMWOLF_CLOSED_BODY_VERIFIED',json.dumps(report),flush=True)
