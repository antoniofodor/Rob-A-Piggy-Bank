"""Check original-body preservation, animation looping, and export round-trip."""
from pathlib import Path
import sys,json,math
from mathutils import Vector
import bpy
root=Path(__file__).resolve().parent
while not (root/'paths.py').exists(): root=root.parent
sys.path.insert(0,str(root));sys.path.insert(0,'/tmp/guard-blender-python')
import paths
out=root.parents[1]/'assets'/'phoenix'
from mathutils.bvhtree import BVHTree
base={}
bpy.ops.wm.open_mainfile(filepath=paths.RAW)
for name in ['Body','Snout','Ears','Legs','Tail']:
    ob=bpy.data.objects[name]; verts=[ob.matrix_world@v.co for v in ob.data.vertices]
    base[name]=(BVHTree.FromPolygons(verts,[tuple(p.vertices) for p in ob.data.polygons]),len(verts))
bpy.ops.wm.open_mainfile(filepath=paths.skin_blend('phoenix'))
surface_errors={}
for name,(bvh,count) in base.items():
    ob=bpy.data.objects[name]
    assert len(ob.data.vertices)<count*.4,(name,'not reduced')
    err=max(bvh.find_nearest(ob.matrix_world@v.co)[3] for v in ob.data.vertices)
    assert err<.06,(name,'source silhouette drift',err)
    surface_errors[name]=err
assert not any('Nostril' in ob.name for ob in bpy.data.objects)
rig=bpy.data.objects['Phoenix_Rig']; scene=bpy.context.scene
parts=[ob for ob in bpy.data.objects if ob.parent==rig and ob.type=='MESH']
assert len(rig.data.bones)==15,len(rig.data.bones)
for ob in parts:
    assert ob.vertex_groups.get(ob['bone'])
    assert all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in ob.data.vertices),ob.name
    assert len(ob.data.uv_layers)==1 and ob.data.uv_layers[0].name=='PhoenixPalette',ob.name
# Compare real deformed vertices, not merely the presence of keyframes.
feather=bpy.data.objects['Crest_1_Orange']
def coords(frame):
    scene.frame_set(frame); dep=bpy.context.evaluated_depsgraph_get(); ev=feather.evaluated_get(dep); m=ev.to_mesh()
    result=[ev.matrix_world@v.co for v in m.vertices];ev.to_mesh_clear();return result
first,mid,last=coords(1),coords(31),coords(121)
movement=max((a-b).length for a,b in zip(first,mid)); loop=max((a-b).length for a,b in zip(first,last))
assert movement>.005,movement
assert loop<1e-5,loop
# Geometry ray checks for the added feathers over the top slot and rear hatch.
from mathutils.bvhtree import BVHTree
verts=[];faces=[]
scene.frame_set(1)
for ob in parts:
    if ob.name in ['Body','Snout','Ears','Legs','Tail','Eyes'] or ob.name.startswith('EyeGlint'):continue
    off=len(verts);verts.extend(ob.matrix_world@v.co for v in ob.data.vertices);faces.extend(tuple(off+i for i in p.vertices) for p in ob.data.polygons)
bvh=BVHTree.FromPolygons(verts,faces)
blocked=[]
for y in [.08,.16,.24,.32,.40,.48]:
    for x in [-.035,0,.035]:
        hit=bvh.ray_cast(Vector((x,y,3)),Vector((0,0,-1)),2.10)
        if hit[0] is not None:blocked.append([x,y])
assert not blocked,('slot covered',blocked)
# The vault is tilted slightly downward. Test circular bore with an outward ray.
normal=Vector((0,math.sqrt(36-1.9**2)/6,-1.9/6)); up=Vector((0,-normal.z,normal.y)); center=Vector((0,1.055,-.039))
blocked_hatch=[]
for i in range(16):
    a=math.tau*i/16; p=center+Vector((1,0,0))*(.20*math.cos(a))+up*(.20*math.sin(a))
    hit=bvh.ray_cast(p+normal*.50,-normal,.55)
    if hit[0] is not None:blocked_hatch.append(i)
assert not blocked_hatch,('hatch covered',blocked_hatch)
report={'source_master_preserved':True,'lowpoly_max_surface_errors':surface_errors,'black_nostril_inserts':0,'weighted_meshes':len(parts),'bones':len(rig.data.bones),'crest_motion_blender_units':movement,'loop_endpoint_error':loop,'slot_rays_clear':18,'hatch_rays_clear':16}
# Exported files must load back with meshes, bones, and animation data.
for filename,kind in [('Phoenix.fbx','fbx'),('Phoenix_Idle.fbx','fbx'),('Phoenix.glb','glb')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if kind=='fbx':bpy.ops.import_scene.fbx(filepath=str(out/filename))
    else:bpy.ops.import_scene.gltf(filepath=str(out/filename))
    meshes=[ob for ob in bpy.data.objects if ob.type=='MESH']; arms=[ob for ob in bpy.data.objects if ob.type=='ARMATURE']
    assert len(meshes)>=len(parts),(filename,len(meshes))
    assert len(arms)==1 and len(arms[0].data.bones)>=15,filename
    if filename!='Phoenix.fbx': assert bpy.data.actions,filename
    assert not any('Preview' in ob.name for ob in meshes),filename
    report[filename]={'meshes':len(meshes),'bones':len(arms[0].data.bones),'actions':len(bpy.data.actions)}
(out/'Phoenix-validation.json').write_text(json.dumps(report,indent=2))
print('PHOENIX_VALIDATED',json.dumps(report))
