"""Isolated beard study: hand-shaped outlines, separate readable layers.

The active game-model package is not overwritten. Render in neutral clay so the
shape can be reviewed independently of the charcoal material and pig silhouette.
"""
from pathlib import Path
import bpy, bmesh, math, json
from mathutils import Vector

OUT=Path(__file__).resolve().parents[1]/'skins/rainbowtiger/beard-shape-study'
OUT.mkdir(parents=True,exist_ok=True)
WIDTH_FULLNESS=2.05
DEPTH_FULLNESS=2.70
# Bring lower layers under the broad middles above them, closing the open
# background wedges without changing the approved individual curve paths.
LAYER_OFFSETS={'LongOuter':(15,-12),'MiddleSweep':(12,-30),'LowerSweep':(-6,-25),
               'LongBottom':(-14,-26)}
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene

def bezier(points,t):
    a,b,c,d=[Vector(p) for p in points]
    return a*(1-t)**3+3*b*(1-t)**2*t+3*c*(1-t)*t*t+d*t**3

# Coordinates follow the supplied close-up's contour, not a swept spike profile.
# Each pair describes the two sides of one lock, sharing a root and a soft tip.
# Depth ordering reveals the long lower strands underneath the short upper fan.
shapes=[
 ('RootPatch',[(105,62),(67,90),(74,177),(168,234)],
              [(105,62),(145,112),(170,219),(168,234)], .19,.140),
 ('LongOuter',[(88,108),(46,161),(130,239),(111,281)],
              [(88,108),(36,190),(86,280),(111,281)], .09,.135),
 ('LongBottom',[(128,193),(143,250),(244,285),(219,321)],
               [(128,193),(91,264),(203,322),(219,321)], .025,.160),
 ('ShortDown',[(99,49),(87,77),(54,111),(51,127)],
              [(99,49),(24,83),(42,126),(51,127)], .00,.105),
 ('ShortOut',[(105,52),(77,25),(48,47),(25,32)],
             [(105,52),(67,76),(28,64),(25,32)], -.025,.105),
 ('LowerSweep',[(133,151),(151,203),(189,249),(231,237)],
               [(133,151),(99,230),(185,282),(231,237)], -.09,.170),
 ('UpperSweep',[(100,56),(129,111),(188,111),(220,84)],
               [(100,56),(77,132),(180,164),(220,84)], -.14,.170),
 ('MiddleSweep',[(91,113),(109,165),(161,188),(186,164)],
                [(91,113),(55,184),(147,228),(186,164)], -.20,.170),
]

mat=bpy.data.materials.new('NeutralClay_ShapeReview');mat.diffuse_color=(.62,.58,.52,1)
mat.use_nodes=True
shader=mat.node_tree.nodes['Principled BSDF']
shader.inputs['Base Color'].default_value=mat.diffuse_color
shader.inputs['Roughness'].default_value=.68
shader.inputs['Specular IOR Level'].default_value=.24

def position(p,y):return Vector(((p.x-135)*.012,y,(170-p.y)*.012))
parts=[];report=[]
for name,left,right,layer,thickness in shapes:
    offset=Vector(LAYER_OFFSETS.get(name,(0,0)))
    left=[Vector(p)+offset for p in left]
    right=[Vector(p)+offset for p in right]
    verts=[];faces=[];uvs=[]
    rings=48;around=24
    # An elliptical cross-section bridges manually shaped inner/outer outlines.
    # No curvature clamps or direction flips can create hooked shoulders.
    for j in range(1,rings):
        t=.5-.5*math.cos(math.pi*j/rings)
        a=bezier(left,t);b=bezier(right,t)
        center=(a+b)*.5
        half=(b-a)*.5*(1.2 if name=='RootPatch' else WIDTH_FULLNESS)
        height=thickness*math.sin(math.pi*t)**.65
        for k in range(around):
            angle=math.tau*k/around
            p=center+half*math.cos(angle)
            verts.append(tuple(position(p,DEPTH_FULLNESS*(layer-height*math.sin(angle)))))
            uvs.append((k/around,t))
    root=len(verts);verts.append(tuple(position(Vector(left[0]),DEPTH_FULLNESS*layer)));uvs.append((.5,0))
    tip=len(verts);verts.append(tuple(position(Vector(left[-1]),DEPTH_FULLNESS*layer)));uvs.append((.5,1))
    for j in range(rings-2):
        for k in range(around):
            faces.append((j*around+k,j*around+(k+1)%around,(j+1)*around+(k+1)%around,(j+1)*around+k))
    for k in range(around):
        faces.append((root,(k+1)%around,k))
        faces.append(((rings-2)*around+k,(rings-2)*around+(k+1)%around,tip))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    ob=bpy.data.objects.new(name,mesh);scene.collection.objects.link(ob);parts.append(ob)
    ob.data.materials.append(mat)
    uv=mesh.uv_layers.new(name='FurFlowUV')
    for loop in mesh.loops:uv.data[loop.index].uv=uvs[loop.vertex_index]
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),name
    bm.to_mesh(mesh);bm.free()
    for p in mesh.polygons:p.use_smooth=True
    report.append({'name':name,'triangles':len(mesh.polygons),'closed':True})

world=bpy.data.worlds.new('StudyBackground');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.19,.22,.26,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
for name,pos,power,size in [('Key',(-4,-5,7),600,5),('Fill',(4,-3,2),170,4),('Rim',(1,3,5),500,3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=pos
    ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('StudyCamera',bpy.data.cameras.new('StudyCamera'));scene.collection.objects.link(camera)
camera.location=(0,-12,0);camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=4.15;scene.camera=camera
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=850;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'beard-layering-study.png');bpy.ops.render.render(write_still=True)

# A single isolated long lock makes the silhouette and taper easy to inspect.
for ob in parts:ob.hide_render=ob.name!='LowerSweep'
camera.data.ortho_scale=2.45;camera.location=(.48,-12,-.42)
camera.rotation_euler=(Vector((.48,0,-.42))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=850;scene.render.resolution_y=850
scene.render.filepath=str(OUT/'single-lock-study.png');bpy.ops.render.render(write_still=True)
for ob in parts:ob.hide_render=False
camera.location=(0,-12,0);camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=4.15
scene.render.resolution_y=1050
scene.render.filepath=str(OUT/'beard-layering-study.png')
bpy.ops.object.select_all(action='DESELECT')
for ob in parts:ob.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.export_scene.fbx(filepath=str(OUT/'beard-shape-study.fbx'),use_selection=True,object_types={'MESH'},bake_anim=False,axis_forward='-Z',axis_up='Y')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'beard-shape-study.blend'))
(OUT/'study-report.json').write_text(json.dumps({'status':'Isolated geometry review; not installed on the game model','width_fullness':WIDTH_FULLNESS,'depth_fullness':DEPTH_FULLNESS,'layer_offsets':LAYER_OFFSETS,'meshes':report,'triangles':sum(p['triangles'] for p in report)},indent=2))
print('BEARD_STUDY_READY',sum(p['triangles'] for p in report),flush=True)
