"""Check actual Dragon animation exports, clearance, and render a four-second loop."""
from pathlib import Path
import bpy,json,math,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
OUT=Path(paths.animal_package('dragon'))
bpy.ops.wm.open_mainfile(filepath=str(OUT/'dragon-complete.blend'));scene=bpy.context.scene
rig=bpy.data.objects['Dragon_Rig'];parts=[o for o in scene.objects if o.type=='MESH' and 'bone' in o]
def pose(r,frame):
    scene.frame_set(frame);return {b.name:b.matrix.copy() for b in r.pose.bones}
def delta(a,b,names):return max(abs(a[n][i][j]-b[n][i][j]) for n in names for i in range(4) for j in range(4))
first=pose(rig,1);last=pose(rig,121);loop=delta(first,last,first);assert loop<1e-5
scene.frame_set(1);known=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(OUT/'dragon-idle.fbx'),use_anim=True)
imports=[o for o in bpy.data.objects if o not in known];import_rig=next(o for o in imports if o.type=='ARMATURE')
assert set(import_rig.pose.bones.keys())==set(rig.pose.bones.keys())
assert import_rig.animation_data and import_rig.animation_data.action
frame_range=list(import_rig.animation_data.action.frame_range);assert abs(frame_range[1]-frame_range[0]-120)<.01
first=pose(import_rig,round(frame_range[0]));middle=pose(import_rig,round(frame_range[0]+30));last=pose(import_rig,round(frame_range[1]))
fbx_loop=delta(first,last,first);assert fbx_loop<1e-4
movements={n:delta(first,middle,[n]) for n in first}
assert movements['Root']<1e-5 and all(movements[n]>.01 for n in ('Tail','Wing_L','Wing_R')),movements
for ob in imports:bpy.data.objects.remove(ob,do_unlink=True)
scene.frame_end=120;scene.render.resolution_x=560;scene.render.resolution_y=560;scene.cycles.samples=8
folder=OUT/'motion';folder.mkdir(exist_ok=True)
N=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized();U=Vector((1,0,0));V=N.cross(U).normalized()
blocked=[];coin_blocked=[];frames=list(range(1,121,3));pulse=[]
for frame in frames:
    scene.frame_set(frame);depsgraph=bpy.context.evaluated_depsgraph_get()
    for ob in parts:
        if ob['bone']=='Root':continue
        evaluated=ob.evaluated_get(depsgraph);m=evaluated.to_mesh()
        tree=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in m.vertices],[list(p.vertices) for p in m.polygons])
        for i in range(24):
            for fraction in (0,.6,1):
                offset=(U*math.cos(i*math.tau/24)+V*math.sin(i*math.tau/24))*1.95*fraction
                if tree.ray_cast(N*10.2+offset,-N,5.7)[0] is not None:blocked.append((frame,ob.name))
        for x in (-.27,0,.27):
            for y in (-1.08,0,1.08):
                if tree.ray_cast(Vector((x,y,13.8)),Vector((0,0,-1)),8.4)[0] is not None:coin_blocked.append((frame,ob.name))
        evaluated.to_mesh_clear()
    nt=bpy.data.objects['Body'].data.materials[0].node_tree
    strength=next(n for n in nt.nodes if n.label=='Dragon ember breath').inputs[1].default_value;pulse.append(strength)
    scene.render.filepath=str(folder/f'frame-{frame:03d}.png');bpy.ops.render.render(write_still=True)
assert not blocked and not coin_blocked,(blocked[:10],coin_blocked[:10])
assert max(pulse)-min(pulse)>1.8
report=dict(sceneSHA256=hashlib.sha256((OUT/'dragon-complete.blend').read_bytes()).hexdigest(),frames=frames,previewFPS=10,seconds=4,sourceFPS=30,sourceFrames=120,boneLoopError=loop,fbxBoneLoopError=fbx_loop,fbxActionFrameRange=frame_range,movementMatrixDeltas=movements,animatedVaultBlocked=blocked,animatedCoinBlocked=coin_blocked,pulseEmissionRange=[min(pulse),max(pulse)])
(OUT/'animation-checks.json').write_text(json.dumps(report,indent=2));print('DRAGON_MOTION_VERIFIED',json.dumps(report),flush=True)
