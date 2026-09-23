"""Validate the delivered idle FBX and render the actual four-second loop."""
from pathlib import Path
import bpy,json,math,sys,hashlib
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
OUT=(Path(paths.animal_package('rainbowtiger')) if '--swept' in sys.argv else Path(paths.skin_study('rainbowtiger','legendary-v1')))
scene_hash=hashlib.sha256((OUT/'rainbowtiger-complete.blend').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(OUT/'rainbowtiger-complete.blend'));scene=bpy.context.scene
rig=bpy.data.objects['RainbowTiger_Rig'];parts=[o for o in scene.objects if o.type=='MESH' and 'bone' in o]
def pose(r,frame):
    scene.frame_set(frame);return {b.name:b.matrix.copy() for b in r.pose.bones}
start=pose(rig,1);end=pose(rig,121)
loop_error=max(abs(start[n][i][j]-end[n][i][j]) for n in start for i in range(4) for j in range(4));assert loop_error<1e-5
scene.frame_set(1);known=set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=str(OUT/'rainbowtiger-idle.fbx'),use_anim=True)
imports=[o for o in bpy.data.objects if o not in known];import_rig=next(o for o in imports if o.type=='ARMATURE')
assert set(import_rig.pose.bones.keys())==set(rig.pose.bones.keys())
assert import_rig.animation_data and import_rig.animation_data.action
frame_range=list(import_rig.animation_data.action.frame_range);assert abs(frame_range[1]-frame_range[0]-120)<.01,frame_range
original=pose(import_rig,round(frame_range[0]));middle=pose(import_rig,round(frame_range[0]+30));last=pose(import_rig,round(frame_range[1]))
fbx_loop=max(abs(original[n][i][j]-last[n][i][j]) for n in original for i in range(4) for j in range(4));assert fbx_loop<1e-4,(frame_range,fbx_loop)
tail_move=max(abs(original['Tail'][i][j]-middle['Tail'][i][j]) for i in range(4) for j in range(4));assert tail_move>.01
root_move=max(abs(original['Root'][i][j]-middle['Root'][i][j]) for i in range(4) for j in range(4));assert root_move<1e-5
for o in imports:bpy.data.objects.remove(o,do_unlink=True)
scene.frame_end=120;scene.render.resolution_x=480 if '--swept' in sys.argv else 520;scene.render.resolution_y=scene.render.resolution_x;scene.cycles.samples=4 if '--swept' in sys.argv else 8
folder=OUT/'motion';folder.mkdir(exist_ok=True)
N=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized();U=Vector((1,0,0));V=N.cross(U).normalized();blocked=[]
frames=list(range(1,121,3));pulse=[];eye_colors=[]
root_checks=json.loads((OUT/'beard-root-checks.json').read_text()) if '--swept' in sys.argv and (OUT/'beard-root-checks.json').exists() else None
root_clearances=[];chin_clearances=[]
render_frames=frames[::2] if '--fast-preview' in sys.argv else frames
for frame in frames:
    scene.frame_set(frame)
    if root_checks:
        for root in root_checks['roots']:
            bone=rig.pose.bones[root.get('bone','Ruff_L' if root['side']<0 else 'Ruff_R')]
            transform=rig.matrix_world@bone.matrix@bone.bone.matrix_local.inverted()
            anchor=transform@(Vector(root['anchorNative'])*6)
            if root.get('attachment')=='undersnout':
                clearance=.03*6-(anchor.z-root['attachmentSurfaceNative'][2]*6)
                assert clearance>0 and anchor.z<-.4*6,('Chin root left lower snout surface',frame,root['lock'])
                chin_clearances.append(clearance)
            else:
                clearance=abs(anchor.x)-root_checks['snoutHalfWidthNative']*6
                assert clearance>.05,('Animated cheek root entered snout width',frame,root['lock'])
                root_clearances.append(clearance)
    # Probe all animated accessory meshes through the biggest rear plate disk.
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for ob in parts:
        if ob['bone']=='Root':continue
        evaluated=ob.evaluated_get(depsgraph);m=evaluated.to_mesh()
        tree=BVHTree.FromPolygons([evaluated.matrix_world@v.co for v in m.vertices],[list(p.vertices) for p in m.polygons])
        for i in range(24):
            for fraction in (.0,.6,1):
                offset=(U*math.cos(i*math.tau/24)+V*math.sin(i*math.tau/24))*1.95*fraction
                if tree.ray_cast(N*10.2+offset,-N,5.7)[0] is not None:blocked.append((frame,ob.name))
        evaluated.to_mesh_clear()
    pulse_materials=['RainbowTiger_BodyCoat'] if '--swept' in sys.argv else ['RainbowTiger_'+name for name in ('Coral','Orange','Gold','Lime','Cyan','Blue','Violet')]
    strengths=[bpy.data.materials[name].node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value for name in pulse_materials]
    pulse.append(strengths)
    eye_colors.append(list(bpy.data.materials['RainbowTiger_Eyes'].node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value[:3]))
    if frame in render_frames:
        scene.render.filepath=str(folder/f'frame-{frame:03d}.png');bpy.ops.render.render(write_still=True)
assert not blocked,blocked[:10]
assert max(row[0] for row in pulse)-min(row[0] for row in pulse)>.8
report={'frames':render_frames,'checkedFrames':frames,'previewFPS':len(render_frames)/4,'seconds':4,'sourceFPS':30,'sourceFrames':120,'boneLoopError':loop_error,'fbxBoneLoopError':fbx_loop,'fbxActionFrameRange':frame_range,'tailMovementMatrixDelta':tail_move,'rootMovementMatrixDelta':root_move,'animatedVaultBlocked':blocked,'pulseEmissionRange':[min(min(r) for r in pulse),max(max(r) for r in pulse)]}
assert max(max(abs(row[i]-eye_colors[0][i]) for i in range(3)) for row in eye_colors)>.5,'Eyes did not cycle RGB'
report['eyesRGBRange']=eye_colors
report['sceneSHA256']=scene_hash
if root_clearances:report['minimumAnimatedRootClearanceStuds']=min(root_clearances)
if chin_clearances:report['minimumChinAttachmentToleranceStuds']=min(chin_clearances)
(OUT/'animation-checks.json').write_text(json.dumps(report,indent=2))
print('RAINBOW_TIGER_MOTION_VERIFIED',json.dumps(report),flush=True)
