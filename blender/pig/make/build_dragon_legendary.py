"""Build Dragon's piggy layout, sculpted accessories, glow and rigged idle.

Reads the original Dragon geometry without overwriting it or the shared master.
Blender -b -t 6 --python-exit-code 1 --python this_file.py -- [--draft]
"""
from pathlib import Path
import sys,math,json,hashlib
import bpy,bmesh
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
import paths
sys.path.insert(0,str(Path(__file__).parent))
import dragon_raised_scales
OUT=Path(paths.animal_package('dragon'));OUT.mkdir(exist_ok=True)
SOURCE=Path(paths.skin_blend('dragon'));MASTER=Path(paths.PARTS)
INPUTS={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE,MASTER,*SOURCE.parent.glob('dragon_*color.png'))}
DRAFT='--draft' in sys.argv;SCALE=6
CORE=['Body','Snout','Ears','Legs','Tail','EyePreview']
RGB={'Horn':(232,203,139),'HornBase':(88,112,69),'WingFrame':(49,83,58),'WingMembrane':(147,66,35),'WingShade':(103,43,29),'Ember':(255,121,27),'Scale':(64,104,66),'ScaleLight':(87,126,73),'Eyes':(36,24,16),'Snout':(55,76,50),'Ground':(151,159,151)}
RGB.update(dragon_raised_scales.PALETTE);RGB['Undercoat']=(35,54,40)
def linear(rgb):return tuple(c/255/12.92 if c/255<=.04045 else ((c/255+.055)/1.055)**2.4 for c in rgb)
def select(obs):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
def material(name,rgb):
    m=bpy.data.materials.new('Dragon_'+name);m.use_nodes=True;m.diffuse_color=(*linear(rgb),1)
    b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=m.diffuse_color;b.inputs['Roughness'].default_value=.72
    return m
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));scene=bpy.context.scene
for ob in list(bpy.data.objects):
    if ob.name not in CORE:bpy.data.objects.remove(ob,do_unlink=True)
mats={k:material(k,v) for k,v in RGB.items()};parts=[];preserved=[]
for name in CORE:
    ob=bpy.data.objects[name];ob.hide_render=False;ob.hide_viewport=False;ob.hide_set(False);ob.hide_select=False
    for mod in list(ob.modifiers):ob.modifiers.remove(mod)
    preserved.append(dict(part=name,vertices=len(ob.data.vertices),positionsSHA256=hashlib.sha256(str([tuple(v.co) for v in ob.data.vertices]).encode()).hexdigest()))
    ob['bone']='Tail' if name=='Tail' else 'Root';parts.append(ob)
    if name in ('Snout','EyePreview'):
        mat=mats['Snout' if name=='Snout' else 'Eyes'];ob.data.materials.clear();ob.data.materials.append(mat)
    if name=='EyePreview':ob.name='Eyes'

# A continuous green undercoat replaces the old belly and heat bands. Narrow
# warm seams are projected from the real plate borders after building them.
for name,m in mats.items():
    node=m.node_tree.nodes.new('ShaderNodeValue');node.label='ALPHA_MASK';node.outputs[0].default_value=0 if name=='Undercoat' else 1
for name in ('Body','Ears','Legs','Tail'):
    dragon_raised_scales.undercoat(bpy.data.objects[name],mats['Undercoat'],mats['ScaleDark'],mats['WingMembrane'])
# Bake opaque undercoat colors and masked emission on the original UVs.
# Individual green plates are geometry added below, not a painted overlay.
scene.render.engine='CYCLES';scene.cycles.samples=1;scene.render.bake.margin=3;scene.render.bake.use_selected_to_active=False
maps=[];glow_materials=[];baked_materials={}
for group,names in [('body',['Body']),('trim',['Snout','Ears','Legs','Tail'])]:
    obs=[bpy.data.objects[n] for n in names];source_mats={m for o in obs for m in o.data.materials if m}
    sheets={}
    for channel in ('color','emissive'):
        image=bpy.data.images.new('Dragon_'+group+'_'+channel,1024,1024,alpha=False)
        if channel=='emissive':image.colorspace_settings.name='Non-Color'
        restored=[]
        for m in source_mats:
            nt=m.node_tree;output=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');surface=output.inputs['Surface'].links[0].from_socket
            emission=nt.nodes.new('ShaderNodeEmission');target=nt.nodes.new('ShaderNodeTexImage');target.image=image;nt.nodes.active=target
            if channel=='color':
                b=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED');c=b.inputs['Base Color']
                if c.is_linked:nt.links.new(c.links[0].from_socket,emission.inputs['Color'])
                else:emission.inputs['Color'].default_value=c.default_value
            else:
                alpha=next((n for n in nt.nodes if n.label=='ALPHA_MASK'),None)
                if alpha:
                    inv=nt.nodes.new('ShaderNodeMath');inv.operation='SUBTRACT';inv.inputs[0].default_value=1
                    nt.links.new(alpha.outputs[0],inv.inputs[1]);nt.links.new(inv.outputs[0],emission.inputs['Color'])
                else:emission.inputs['Color'].default_value=(0,0,0,1)
            nt.links.new(emission.outputs[0],output.inputs['Surface']);restored.append((nt,output,surface,emission,target))
        select(obs);bpy.ops.object.bake(type='EMIT')
        path=OUT/f'dragon_{group}_{channel}.png';dragon_raised_scales.save_png(image,path);image.pack();sheets[channel]=image
        maps.append(dict(file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        for nt,output,surface,emission,target in restored:nt.links.new(surface,output.inputs['Surface']);nt.nodes.remove(emission);nt.nodes.remove(target)
    m=material(group,(255,255,255));nt=m.node_tree;b=nt.nodes['Principled BSDF'];b.inputs['Roughness'].default_value=.8
    color=nt.nodes.new('ShaderNodeTexImage');color.label='Scale undercoat color';color.image=sheets['color'];nt.links.new(color.outputs['Color'],b.inputs['Base Color']);nt.links.new(color.outputs['Color'],b.inputs['Emission Color'])
    mask=nt.nodes.new('ShaderNodeTexImage');mask.label='Scale seam mask';mask.image=sheets['emissive'];baked_materials[group]=m
    gain=nt.nodes.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.label='Dragon ember breath';nt.links.new(mask.outputs['Color'],gain.inputs[0]);nt.links.new(gain.outputs[0],b.inputs['Emission Strength']);glow_materials.append((m,gain.inputs[1]))
    for ob in obs:
        for i in range(len(ob.data.materials)):ob.data.materials[i]=m

body=bpy.data.objects['Body'];tree=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
def surface(y,theta,side):
    direction=Vector((side*math.sin(theta),0,math.cos(theta)))
    hit,n,_,_=tree.ray_cast(Vector((0,y,0))+direction*3,-direction,3.1)
    assert hit is not None,(y,theta,side)
    return hit,n
def mesh(name,verts,faces,tone,bone='Root'):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.data.materials.append(mats[tone]);ob['bone']=bone;ob['tone']=tone;parts.append(ob);return ob
def tube(name,points,radii,tone,bone='Root',sides=8):
    points=[Vector(p) for p in points];verts=[];faces=[]
    for i,p in enumerate(points):
        d=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized();u=d.cross(Vector((0,1,0)))
        if u.length<.01:u=d.cross(Vector((1,0,0)))
        u.normalize();v=d.cross(u).normalized()
        for j in range(sides):verts.append(tuple(p+radii[i]*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides))))
    faces.append(tuple(reversed(range(sides))))
    for i in range(len(points)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    faces.append(tuple((len(points)-1)*sides+j for j in range(sides)))
    return mesh(name,verts,faces,tone,bone)
def plate(name,outline,center,thickness,tone,bone='Root'):
    # Closed, ridged polygon, with separate front/back fan faces.
    outline=[Vector(p) for p in outline];center=Vector(center);n=len(outline)
    verts=[tuple(p+Vector((0,-thickness/2,0))) for p in outline]+[tuple(p+Vector((0,thickness/2,0))) for p in outline]
    verts += [tuple(center+Vector((0,-thickness,0))),tuple(center+Vector((0,thickness/2,0)))]
    faces=[]
    for i in range(n):j=(i+1)%n;faces.extend([(2*n,i,j),(2*n+1,n+j,n+i),(i,n+i,n+j,j)])
    return mesh(name,verts,faces,tone,bone)

scale_report,seam_sources=dragon_raised_scales.build([bpy.data.objects[n] for n in ('Body','Ears','Legs','Tail')],mesh)
scale_report['seamMasks']=dragon_raised_scales.bake_seams(seam_sources,baked_materials,OUT,select,linear)
for entry in maps:entry['sha256']=hashlib.sha256((OUT/entry['file']).read_bytes()).hexdigest()

for side,label in [(-1,'L'),(1,'R')]:
    h,n=surface(-.16,.53,side)
    tube('Horn_'+label,[h-n*.045,h+Vector((side*.09,.03,.17)),h+Vector((side*.12,.14,.41)),h+Vector((side*.08,.29,.55))],[.12,.106,.055,.003],'Horn')
    # Small swept cheek horns reinforce the dragon face without hiding eyes.
    h,n=surface(-.58,1.18,side)
    tube('CheekHorn_'+label,[h-n*.025,h+Vector((side*.17,.05,.03)),h+Vector((side*.27,.18,.12))],[.07,.046,.003],'Horn')
    bone='Wing_'+label
    root=Vector((side*.72,.18,.35));elbow=Vector((side*1.06,.27,1.04));tip=Vector((side*1.61,.53,1.36))
    fingers=[tip,Vector((side*1.57,.71,.77)),Vector((side*1.37,.79,.31)),Vector((side*.93,.65,.08))]
    tube('WingArm_'+label,[root,elbow,tip],[.085,.075,.008],'WingFrame',bone)
    for i in range(3):
        a,b=fingers[i:i+2];scallop=a.lerp(b,.55).lerp(root,.18)
        center=(root+a+b)/3
        plate('WingWeb_'+label+str(i),[root,a,scallop,b],center,.033,'WingMembrane' if i%2==0 else 'WingShade',bone)
        tube('WingFinger_'+label+str(i),[root,root.lerp(b,.55)+Vector((0,0,.055)),b],[.038,.024,.004],'WingFrame',bone,6)
        tube('WingEmber_'+label+str(i),[root.lerp(a,.20),root.lerp(a,.62),a],[.018,.013,.002],'Ember',bone,6)
    # Twin low ridges frame the central coin slot, leaving the crown accessible.
    for j,y in enumerate((.12,.39,.65,.81)):
        h,n=surface(y,.26,side)
        tube('Spine_'+label+str(j),[h-n*.025,h+n*(.16 if j<3 else .11)+Vector((0,.06,0)),h+n*(.25 if j<3 else .17)+Vector((0,.13,0))],[.08,.052,.002],'Horn')

tail_pivot=Vector((0,.77,.29))
plate('TailFin',[(-.13,1.35,.57),(-.15,1.56,.74),(0,1.69,.91),(.15,1.56,.74),(.13,1.35,.57)],(0,1.50,.72),.06,'WingMembrane','Tail')
tube('TailEmber',[(0,1.40,.59),(0,1.55,.74),(0,1.69,.91)],[.034,.026,.002],'Ember','Tail')

# Join accessories that share a material and rigid bone, keeping the six
# source parts separate and reducing importer parts/draw calls.
groups={}
for ob in parts[6:]:groups.setdefault((ob['bone'],ob['tone']),[]).append(ob)
parts=parts[:6]
for (bone,tone),obs in groups.items():
    select(obs)
    if len(obs)>1:bpy.ops.object.join()
    ob=bpy.context.object
    ob.name='Dragon_'+bone+'_'+tone;ob['bone']=bone;ob['tone']=tone;parts.append(ob)

# A four-second breath, with a restrained wing lift and little tail sway.
N=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized();U=Vector((1,0,0));V=N.cross(U).normalized()
added=[o for o in parts if o.name not in ('Body','Snout','Ears','Legs','Tail','Eyes')]
blocked=[];coin_blocked=[]
for ob in added:
    t=BVHTree.FromPolygons([v.co for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons])
    for i in range(48):
        for frac in (0,.5,1):
            offset=(U*math.cos(i*math.tau/48)+V*math.sin(i*math.tau/48))*(1.95/6)*frac
            if t.ray_cast(N*1.7+offset,-N,.95)[0] is not None:blocked.append(ob.name)
    for x in (-.045,0,.045):
        for y in (-.18,0,.18):
            if t.ray_cast(Vector((x,y,2.3)),Vector((0,0,-1)),1.4)[0] is not None:coin_blocked.append(ob.name)
assert not blocked and not coin_blocked,(blocked,coin_blocked)
checks=[]
for ob in parts:
    select([ob]);ob.scale*=SCALE;ob.location*=SCALE;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bad=sum(not e.is_manifold for e in bm.edges);bm.to_mesh(ob.data);bm.free()
    assert bad==0 and len(ob.data.polygons)<20000,(ob.name,bad,len(ob.data.polygons))
    checks.append(dict(name=ob.name,bone=ob['bone'],triangles=len(ob.data.polygons),nonManifoldEdges=bad,tone=ob.get('tone'),colorRGB=RGB.get(ob.get('tone'))))
bones={'Root':(Vector((0,0,0)),None),'Tail':(tail_pivot*SCALE,'Root'),'Wing_L':(Vector((-.72,.18,.35))*SCALE,'Root'),'Wing_R':(Vector((.72,.18,.35))*SCALE,'Root')}
arm=bpy.data.armatures.new('Dragon_Skeleton');rig=bpy.data.objects.new('Dragon_Rig',arm);scene.collection.objects.link(rig);select([rig]);bpy.ops.object.mode_set(mode='EDIT')
for name,(pivot,parent) in bones.items():
    b=arm.edit_bones.new(name);b.head=pivot;b.tail=pivot+Vector((0,0,1))
    if parent:b.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for ob in parts:
    ob.vertex_groups.clear();vg=ob.vertex_groups.new(name=ob['bone']);vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    ob.parent=rig;mod=ob.modifiers.new('DragonRig','ARMATURE');mod.object=rig
scene.render.fps=30;scene.frame_start=1;scene.frame_end=121
for name in bones:
    pb=rig.pose.bones[name];pb.rotation_mode='QUATERNION';q=pb.bone.matrix_local.to_quaternion()
    for frame in range(1,122,4):
        wave=math.sin(math.tau*(frame-1)/120);angle=math.radians(3 if name=='Tail' else 5)*wave*(1 if name!='Wing_R' else -1) if name!='Root' else 0
        axis=Vector((0,0,1)) if name=='Tail' else Vector((0,1,0));pb.rotation_quaternion=q.inverted()@Quaternion(axis,angle)@q;pb.keyframe_insert('rotation_quaternion',frame=frame,group=name)
rig.animation_data.action.name='Dragon_Idle'
b=mats['Ember'].node_tree.nodes['Principled BSDF'];b.inputs['Emission Color'].default_value=(*linear(RGB['Ember']),1);glow_materials.append((mats['Ember'],b.inputs['Emission Strength']))
for mat,socket in glow_materials:
    for frame in range(1,122,4):
        socket.default_value=.35+1.85*(.5-.5*math.cos(math.tau*(frame-1)/120))**2;socket.keyframe_insert('default_value',frame=frame)
scene.frame_set(1);select(parts+[rig])
common=dict(use_selection=True,object_types={'MESH','ARMATURE'},axis_forward='-Z',axis_up='Y',add_leaf_bones=False,armature_nodetype='NULL',path_mode='COPY',embed_textures=True,use_triangles=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False)
bpy.ops.export_scene.fbx(filepath=str(OUT/'dragon-complete.fbx'),bake_anim=False,**common)
bpy.ops.export_scene.fbx(filepath=str(OUT/'dragon-idle.fbx'),bake_anim=True,bake_anim_simplify_factor=0,**common)
def bounds(obs):
    pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
    return {k:[fn(v[i] for v in pts) for i in range(3)] for k,fn in [('min',min),('max',max)]}
before=bounds(parts);known=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(OUT/'dragon-complete.fbx'),use_anim=False)
imports=[o for o in bpy.data.objects if o not in known];meshes=[o for o in imports if o.type=='MESH'];after=bounds(meshes)
error=max(abs(a-b) for k in before for a,b in zip(before[k],after[k]));assert error<.001 and len(meshes)==len(parts),(error,len(meshes),len(parts))
assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==sum(r['triangles'] for r in checks)
assert all(o.vertex_groups for o in meshes)
for ob in imports:bpy.data.objects.remove(ob,do_unlink=True)
report=dict(skin='dragon',rarity='legendary',chest='animal',status='First model revision; Studio integration pending',inputHashes=INPUTS,preservedSourceParts=preserved,maps=maps,meshCount=len(parts),triangles=sum(r['triangles'] for r in checks),meshes=checks,bodyWidthStuds=12,sourceToStudScale=6,boundsStuds=before,fbxRoundTripBoundsError=error,addedGeometryVaultBlocked=blocked,addedGeometryCoinBlocked=coin_blocked,animation=dict(periodSeconds=4,fps=30,frames=[1,121],wingLiftDegrees=5,tailSwayDegrees=3,emissionMin=.35,emissionMax=2.2,pulseCurve='0.35 + 1.85 * (0.5 - 0.5*cos(2*pi*time/4))^2',bones={n:dict(pivotStuds=list(v),parent=p) for n,(v,p) in bones.items()},notes='Idle FBX contains bone animation. Body/trim masks and Ember parts require client-side emission playback in Studio.'))
report['raisedScales']=scale_report;report['status']='Raised-scale revision; continuous breathing glow; Studio integration pending'
(OUT/'dragon-asset-report.json').write_text(json.dumps(report,indent=2));(OUT/'animation-handoff.json').write_text(json.dumps(report['animation'],indent=2))
world=bpy.data.worlds.new('DragonReview');world.use_nodes=True;scene.world=world;world.node_tree.nodes['Background'].inputs[0].default_value=(.48,.54,.62,1);world.node_tree.nodes['Background'].inputs[1].default_value=.65
for name,pos,power,size in [('Key',(-20,-27,35),4500,22),('Fill',(25,-10,16),2800,20),('Rim',(3,22,28),4000,18)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;ob=bpy.data.objects.new('REVIEW_'+name,data);scene.collection.objects.link(ob);ob.location=pos;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,before['min'][2]-.03));bpy.context.object.name='REVIEW_Ground';bpy.context.object.data.materials.append(mats['Ground'])
cam=bpy.data.objects.new('REVIEW_Camera',bpy.data.cameras.new('REVIEW_Camera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=24
scene.cycles.samples=8 if DRAFT else 24;scene.cycles.use_denoising=True;scene.render.resolution_x=640 if DRAFT else 900;scene.render.resolution_y=scene.render.resolution_x;scene.render.resolution_percentage=100;scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
sys.path.insert(0,str(Path(__file__).parent));from stormwolf_lightning import compositor;compositor(scene)
scene.frame_set(61)
shots=[('hero',(-25,-33,18),(0,.1,1)),('front',(0,-36,11),(0,0,1)),('crown',(-8,-21,34),(0,0,2)),('rear',(0,35,13),(0,1,1))]
shots.append(('scales',(-22,-10,9),(-4,-1,1)))
for name,pos,target in shots:
    cam.data.ortho_scale=8 if name=='scales' else 24;scene.frame_set(1 if name=='scales' else 61)
    cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/f'dragon-{name}.png');bpy.ops.render.render(write_still=True)
cam.data.ortho_scale=24;cam.location=shots[0][1];cam.rotation_euler=(Vector(shots[0][2])-cam.location).to_track_quat('-Z','Y').to_euler();scene.frame_set(1)
select(parts+[rig]);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dragon-complete.blend'))
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==sha for p,sha in INPUTS.items())
print('DRAGON_READY',json.dumps(dict(meshes=len(parts),triangles=report['triangles'],fbxError=error)),flush=True)
