"""Check actual Phoenix animation exports, clearance, and render a four-second loop."""
from pathlib import Path
import bpy,json,math,hashlib,sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
OUT=Path(paths.animal_package('phoenix'))
source_hash=hashlib.sha256((OUT/'phoenix-complete.blend').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(OUT/'phoenix-complete.blend'));scene=bpy.context.scene
asset=json.loads((OUT/'phoenix-asset-report.json').read_text())
assert sum(o.get('bone') is not None for o in scene.objects if o.type=='MESH') == asset['meshCount']
rig=bpy.data.objects['Phoenix_Rig'];parts=[o for o in scene.objects if o.type=='MESH' and 'bone' in o]
def pose(r,frame):
    scene.frame_set(frame);return {b.name:b.matrix.copy() for b in r.pose.bones}
def delta(a,b,names):return max(abs(a[n][i][j]-b[n][i][j]) for n in names for i in range(4) for j in range(4))
first=pose(rig,1);last=pose(rig,121);loop=delta(first,last,first);assert loop<1e-5
scene.frame_set(1);known=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(OUT/'phoenix-idle.fbx'),use_anim=True)
imports=[o for o in bpy.data.objects if o not in known];import_rig=next(o for o in imports if o.type=='ARMATURE')
assert set(import_rig.pose.bones.keys())==set(rig.pose.bones.keys())
assert import_rig.animation_data and import_rig.animation_data.action
frame_range=list(import_rig.animation_data.action.frame_range);assert abs(frame_range[1]-frame_range[0]-120)<.01
first=pose(import_rig,round(frame_range[0]));middle=pose(import_rig,round(frame_range[0]+30));last=pose(import_rig,round(frame_range[1]))
fbx_loop=delta(first,last,first);assert fbx_loop<1e-4
samples=[pose(import_rig,round(frame_range[0]+offset)) for offset in (30,60,90)]
movements={n:max(delta(first,sample,[n]) for sample in samples) for n in first}
assert movements['Root']<1e-5 and all(movements[n]>.01 for n in ('Tail','Mantle_L','Mantle_R','Crest_0','Crest_1','Crest_2','Ruff_L','Ruff_R')),movements
for ob in imports:bpy.data.objects.remove(ob,do_unlink=True)
scene.frame_end=120;scene.render.resolution_x=560;scene.render.resolution_y=560;scene.cycles.samples=8
folder=OUT/'motion';folder.mkdir(exist_ok=True)
sys.path.insert(0,str(Path(__file__).parent))
from phoenix_vault_geometry import vault_blocked
blocked=[];coin_blocked=[];frames=list(range(1,121,3));pulse=[];root_motion=0
check_only='--check-only' in sys.argv
pinned={o.name:[v.index for v in o.data.vertices if o.data.attributes['TipWeight'].data[v.index].value<1e-6] for o in parts if o['bone'] not in ('Root','Tail') and o.data.attributes.get('TipWeight')}
assert sum(map(len,pinned.values()))>100
for frame in frames:
    scene.frame_set(frame);depsgraph=bpy.context.evaluated_depsgraph_get()
    for ob in parts:
        if ob['bone']=='Root':continue
        evaluated=ob.evaluated_get(depsgraph);m=evaluated.to_mesh()
        for i in pinned.get(ob.name,[]):
            root_motion=max(root_motion,(evaluated.matrix_world@m.vertices[i].co-ob.matrix_world@ob.data.vertices[i].co).length)
        tree=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in m.vertices],[list(p.vertices) for p in m.polygons])
        if vault_blocked(tree,scale=6):blocked.append((frame,ob.name))
        for x in (-.27,0,.27):
            for y in (0,.54,1.08,1.62,2.16,2.70,3.15):
                if tree.ray_cast(Vector((x,y,13.8)),Vector((0,0,-1)),8.4)[0] is not None:coin_blocked.append((frame,ob.name))
        evaluated.to_mesh_clear()
    nt=bpy.data.objects['Phoenix_Crest_0_Feathers'].data.materials[0].node_tree
    strength=next(n for n in nt.nodes if n.label=='Phoenix frost shimmer').inputs[1].default_value;pulse.append(strength)
    if not check_only:
        scene.render.filepath=str(folder/f'frame-{frame:03d}.png');bpy.ops.render.render(write_still=True)
assert not blocked and not coin_blocked,(blocked[:10],coin_blocked[:10])
assert max(pulse)-min(pulse)>1.4
assert root_motion<1e-5,root_motion
assert hashlib.sha256((OUT/'phoenix-complete.blend').read_bytes()).hexdigest()==source_hash, 'Source scene changed during rendering'
report=dict(sceneSHA256=source_hash,frames=frames,previewFPS=10,seconds=4,sourceFPS=30,sourceFrames=120,boneLoopError=loop,fbxBoneLoopError=fbx_loop,fbxActionFrameRange=frame_range,movementMatrixDeltas=movements,animatedVaultBlocked=blocked,animatedCoinBlocked=coin_blocked,pulseEmissionRange=[min(pulse),max(pulse)])
report.update(pinnedRootMaxMotion=root_motion,pinnedRootVertexCount=sum(map(len,pinned.values())))
(OUT/('animation-preflight.json' if check_only else 'animation-checks.json')).write_text(json.dumps(report,indent=2));print('ICE_PHOENIX_MOTION_VERIFIED',json.dumps(report),flush=True)
