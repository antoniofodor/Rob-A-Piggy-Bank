"""Approved Phoenix: existing pig geometry + rigid-weighted feather layers.
Run Blender -b --python this_file.py. Use -- --no-render for exports only.
Generated outputs are disposable; this script and approved concept are the sources.
"""
from pathlib import Path
import sys, math, json, argparse, struct, zlib
HERE=Path(__file__).resolve().parent
root=HERE
while not (root/'paths.py').exists(): root=root.parent
sys.path.insert(0,str(root)); sys.path.insert(0,'/tmp/guard-blender-python')
import paths
import bpy, bmesh
from mathutils import Vector, Quaternion
args=argparse.ArgumentParser(); args.add_argument('--no-render',action='store_true')
args=args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=root.parents[1]/'assets'/'phoenix'; OUT.mkdir(parents=True,exist_ok=True)
# Physical source remains untouched. Source axes: Z up, face -Y; 6 studs/unit.
bpy.ops.wm.open_mainfile(filepath=paths.RAW)
KEEP={'Body','Snout','Ears','Legs','Tail','EyePreview'}
for ob in list(bpy.data.objects):
    if ob.name not in KEEP: bpy.data.objects.remove(ob,do_unlink=True)
scene=bpy.context.scene
for c in list(bpy.data.collections):
    if not c.objects and not c.children: bpy.data.collections.remove(c)
asset=bpy.data.collections.new('PHOENIX • export geometry'); scene.collection.children.link(asset)
fx=bpy.data.collections.new('PREVIEW ONLY • flames and embers'); scene.collection.children.link(fx)
stage=bpy.data.collections.new('STUDIO • cameras and lighting'); scene.collection.children.link(stage)
RGB={'Gold':(255,177,20),'Sun':(255,214,57),'Amber':(255,133,12),'Orange':(245,80,10),'Vermilion':(217,40,15),'Crimson':(148,15,24),'Wine':(85,12,24),'Eye':(20,12,9),'Glow':(255,206,49)}
def linear(v):
    v=v/255; return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
mats={}
for key,rgb in RGB.items():
    m=bpy.data.materials.new('Phoenix_'+key); m.diffuse_color=(*[linear(v) for v in rgb],1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=.58 if key!='Eye' else .22
    if key=='Glow':
        p.inputs['Emission Color'].default_value=m.diffuse_color; p.inputs['Emission Strength'].default_value=2.8
    mats[key]=m

def move_collection(ob,col):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    col.objects.link(ob)
parts=[]; bones={'Root':((0,0,0),None)}; feather_count=0

def bind_spec(ob,tone,bone):
    ob.hide_render=False; ob.hide_set(False); ob.hide_viewport=False
    move_collection(ob,asset); ob['tone']=tone; ob['bone']=bone
    parts.append(ob); return ob

base_counts={}; lowpoly_counts={}
for name in sorted(KEEP):
    ob=bpy.data.objects[name]; base_counts[name]=len(ob.data.vertices)
    # Phoenix-specific low-poly copies, preserving the shared authoring master.
    bpy.ops.object.select_all(action='DESELECT'); ob.hide_set(False); ob.select_set(True); bpy.context.view_layer.objects.active=ob
    dec=ob.modifiers.new('Phoenix_LowPoly','DECIMATE')
    dec.ratio={'Body':.16,'Snout':.23,'Ears':.085,'Legs':.23,'Tail':.25,'EyePreview':.22}[name]
    bpy.ops.object.modifier_apply(modifier=dec.name)
    lowpoly_counts[name]=len(ob.data.vertices)
    for face in ob.data.polygons: face.use_smooth=name=='EyePreview'
    tone={'Body':'Orange','Snout':'Gold','Ears':'Gold','Legs':'Crimson','Tail':'Gold','EyePreview':'Eye'}[name]
    ob.data.materials.clear()
    for m in mats.values(): ob.data.materials.append(m)
    keys=list(mats)
    for p in ob.data.polygons:
        co=ob.matrix_world @ p.center; chosen=tone
        if name=='Body': chosen='Gold' if co.y<-.43 else ('Amber' if co.y<-.08 else ('Vermilion' if co.y<.48 else 'Crimson'))
        if name=='Legs' and co.z<-.87: chosen='Gold'
        p.material_index=keys.index(chosen)
    bind_spec(ob,tone,'Root')
    if name=='EyePreview': ob.name='Eyes'

def newbone(name,pivot,parent='Root'):
    bones[name]=(tuple(pivot),parent); return name

# A broad convex, curved leaf: six cross sections, a raised midrib, closed back.
# Local direction follows the feather's spine; normal points away from the body.
def feather(name,start,direction,normal,length,width,tone,bone,hot=False,drape=False):
    global feather_count
    start=Vector(start); d=Vector(direction).normalized(); n=Vector(normal).normalized()
    n=(n-d*n.dot(d)).normalized(); side=d.cross(n).normalized()
    ts=[0,.48,.86,1] if hot else [0,.40,.78,1]; ws=[.10,1,.46,0] if hot else [.10,1,.65,0]
    verts=[]
    for t,w in zip(ts,ws):
        center=start+d*(length*t)+n*(length*((-.20 if drape else .14)*t*t+.04*math.sin(math.pi*t)))+side*(length*(.30 if hot else .10)*t*t)
        for a,h in [(-1,0),(0,.025),(1,0),(0,-.012)]:
            verts.append(tuple(center+side*(width*.5*w*a)+n*(h*math.sin(math.pi*t))))
    faces=[]; midx=[]
    palette=[tone,'Amber' if hot else tone,'Glow' if hot else tone]
    for i in range(3):
        for a,b in [(0,1),(1,2),(2,3),(3,0)]:
            faces.append((4*i+a,4*(i+1)+a,4*(i+1)+b,4*i+b)); midx.append(2 if hot and i==2 else 1 if hot and i==1 else 0)
    faces.extend([(3,2,1,0),(12,13,14,15)]); midx.extend([0,2 if hot else 0])
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    for p,idx in zip(mesh.polygons,midx): p.material_index=idx
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(mesh); bm.free()
    ob=bpy.data.objects.new(name,mesh); asset.objects.link(ob)
    for key in palette: mesh.materials.append(mats[key])
    feather_count+=1; bind_spec(ob,tone,bone); ob['glow_tip']=hot
    return ob

# Mantle layers drape from the shoulder toward the feet; keep the golden face open.
for row,theta in enumerate([.58,1.10,1.65]):
    count=[10,12,12][row]
    for j in range(count):
        phi=2*math.pi*(j+(row%2)*.5)/count
        x=math.sin(theta)*math.cos(phi); y=1.08*math.sin(theta)*math.sin(phi); z=.96*math.cos(theta)
        if y<-.48: continue
        if abs(x)<.17 and z>.77 and -.05<y<.68: continue # coin slot clearance
        if y>.60 and abs(x)<.68 and z<.68: continue # vault plate clearance
        side='L' if x<0 else 'R'; sector='Front' if y<.1 else 'Back'
        bn='Mantle_'+side+'_'+sector
        if bn not in bones: newbone(bn,(.5*(-1 if x<0 else 1),.2 if sector=='Front' else .65,.3))
        normal=Vector((x,y/1.08**2,z/.96**2)).normalized()
        d=Vector((math.cos(theta)*math.cos(phi),math.cos(theta)*math.sin(phi),-math.sin(theta)))
        # Tips lean rearward, with layered red/orange bands.
        d=(d+Vector((0,.24,0))).normalized()
        tone='Amber' if y<-.05 else ('Orange' if y<.32 else ('Vermilion' if row<2 else 'Crimson'))
        feather('Mantle_%02d_%02d'%(row,j),Vector((x,y,z))+normal*.015,d,normal,.67 if row<2 else .53,.58 if row<2 else .54,tone,bn,drape=True)

# Face ruff: two cheek fans, swept outward and down, framing rather than covering eyes.
for sign,label in [(-1,'L'),(1,'R')]:
    bn=newbone('Ruff_'+label,(sign*.62,-.56,.10))
    for k in range(3):
        angle=math.radians(65+27*k)
        # From temples to lower jaw on the front hemisphere.
        x=sign*(.64-.055*k); z=.34-.35*k
        start=(x,-.65 if k<3 else -.59,z)
        d=(sign*.54,.20,-.38 if k==0 else -.65)
        feather('Ruff_'+label+str(k),start,d,(sign*.5,-1,.12),.57,.39,'Amber' if k%2 else 'Orange',bn,hot=k==1)
    # Golden facial edge feathers, smaller and flatter.
    for k in range(2):
        x=sign*(.51-.07*k); z=-.02-.34*k
        feather('Face_'+label+str(k),(x,-.80,z),(sign*.40,.12,-.85),(sign*.30,-1,.10),.45,.36,'Gold','Root')

# Crest sits in FRONT of the slot; individual feathers can flex independently.
for i,(x,y,z,L) in enumerate([(-.12,-.49,.86,.72),(.10,-.40,.92,.88),(0,-.64,.78,.54)]):
    bn=newbone('Crest_'+str(i),(x,y,z))
    feather('Crest_'+str(i),(x,y,z),(.32 if i==0 else .18,.22,1),(0,-1,0),L,.43,'Orange' if i<2 else 'Amber',bn,True)

# Tail fan above the hatch. Curly tail remains visible in front of these leaves.
for i,ang in enumerate([-65,-33,0,33,65]):
    a=math.radians(ang); p=(.12*math.sin(a),1.02,.41)
    bn=newbone('TailFan_'+str(i),p)
    feather('TailFan_'+str(i),p,(math.sin(a),.10,math.cos(a)),(0,1,0),.78 if i==2 else .67,.32,'Orange' if i%2 else 'Vermilion',bn,True)

# Small catchlights are geometry and remain easy to recolor/remove.
for sign in [-1,1]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.021,location=(sign*.304,-.963,.410))
    ob=bpy.context.object; ob.name='EyeGlint_'+str(sign); ob.data.materials.append(mats['Sun']); bind_spec(ob,'Sun','Root')

# Consolidate same bone/material meshes; split emissive tips into their own MeshParts.
# Roblox can then set only those small pieces to Neon, independent of the coat.
for ob in list(parts):
    if not ob.name.startswith(('Mantle','Ruff','Face','Crest','TailFan')): continue
    if ob.get('glow_tip'):
        # Separate by material, preserving custom properties and bone assignment.
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active=ob
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
parts=[ob for ob in asset.objects if ob.type=='MESH']
for ob in parts:
    if any(m and m.name=='Phoenix_Glow' for m in ob.data.materials):
        used={p.material_index for p in ob.data.polygons}
        if all(ob.data.materials[i].name=='Phoenix_Glow' for i in used): ob['tone']='Glow'
# Join feather groups by bone and actual material. Preserve the original five pieces.
groups={}
for ob in parts:
    if ob.name.startswith(('Body','Snout','Ears','Legs','Tail','Eyes','EyeGlint')) and not ob.name.startswith('TailFan'): continue
    used=tuple(sorted(set(ob.data.materials[p.material_index].name for p in ob.data.polygons)))
    groups.setdefault((ob['bone'],used),[]).append(ob)
for (bn,used),obs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs: ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]; bpy.ops.object.join()
    ob=obs[0]; ob.name=bn+'_'+used[0].removeprefix('Phoenix_'); ob['tone']=used[0].removeprefix('Phoenix_')
parts=[ob for ob in asset.objects if ob.type=='MESH']
# Portable color atlas: Roblox can use this single texture if FBX materials are lost.
# These are copies of the source meshes; the original pig UVs remain untouched.
colors=list(RGB); w=len(colors)*32; h=32
raw=b''.join(b'\0'+b''.join(bytes(RGB[colors[x//32]]) for x in range(w)) for _ in range(h))
def chunk(kind,data): return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
atlas=OUT/'Phoenix_palette.png'
atlas.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
im=bpy.data.images.load(str(atlas),check_existing=True); im.pack()
for ob in parts:
    for old_uv in list(ob.data.uv_layers): ob.data.uv_layers.remove(old_uv)
    uv=ob.data.uv_layers.new(name='PhoenixPalette')
    ob.data.uv_layers.active=uv; uv.active_render=True
    for p in ob.data.polygons:
        tone=ob.data.materials[p.material_index].name.removeprefix('Phoenix_')
        u=(colors.index(tone)+.5)/len(colors)
        for j,li in enumerate(p.loop_indices): uv.data[li].uv=(u+(.01 if j%2 else -.01),.5+(.1 if j<2 else -.1))
for m in mats.values():
    tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im; tex.interpolation='Closest'
    uvnode=m.node_tree.nodes.new('ShaderNodeUVMap'); uvnode.uv_map='PhoenixPalette'
    m.node_tree.links.new(uvnode.outputs['UV'],tex.inputs['Vector'])
    m.node_tree.links.new(tex.outputs['Color'],m.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
arm=bpy.data.armatures.new('Phoenix_Skeleton'); rig=bpy.data.objects.new('Phoenix_Rig',arm); asset.objects.link(rig)
bpy.context.view_layer.objects.active=rig; rig.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
for name,(pivot,parent) in bones.items():
    bone=arm.edit_bones.new(name); bone.head=pivot; bone.tail=Vector(pivot)+Vector((0,0,.16))
    if parent: bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front=True
for ob in parts:
    ob.vertex_groups.clear(); vg=ob.vertex_groups.new(name=ob['bone']); vg.add(list(range(len(ob.data.vertices))),1,'REPLACE')
    ob.parent=rig; mod=ob.modifiers.new('Phoenix_FeatherRig','ARMATURE'); mod.object=rig
# Loop with matching first and last frames. Base pig stays still for game vault alignment.
scene.render.fps=30; scene.frame_start=1; scene.frame_end=121
act=bpy.data.actions.new('Phoenix_Idle'); act.use_fake_user=True; rig.animation_data_create(); rig.animation_data.action=act
for index,(name,spec) in enumerate(bones.items()):
    pb=rig.pose.bones[name]; pb.rotation_mode='QUATERNION'
    for frame in range(1,122,4):
        phase=2*math.pi*(frame-1)/120; amp=0 if name=='Root' else math.radians(3 if name.startswith('Mantle') else 5)
        axis=Vector((1,0,.25 if name.startswith('Ruff') else .08)).normalized()
        q=pb.bone.matrix_local.to_quaternion(); pb.rotation_quaternion=q.inverted()@Quaternion(axis,amp*math.sin(phase+index*.63))@q
        pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=name)
scene.frame_set(1)
# Preview-only flame tongues and ember motes; FBX deliberately excludes this collection.
for i,(x,y,z) in enumerate([(.16,-.28,1.64),(0,1.10,1.16)]):
    ob=feather('PreviewFlame_'+str(i),(0,0,0),(.15,0,1),(0,-1,0),.16,.070,'Glow','Root')
    parts.remove(ob); move_collection(ob,fx); ob.location=(x,y,z)
    for f in range(1,122,4):
        p=2*math.pi*(f-1)/120+i; ob.scale=(.8+.2*math.sin(p),1,.75+.3*math.sin(p)); ob.keyframe_insert(data_path='scale',frame=f)
for i in range(6):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.017)
    ob=bpy.context.object; ob.name='PreviewEmber_%02d'%i; move_collection(ob,fx); ob.data.materials.append(mats['Glow'])
    a=i*2.399; base=Vector((1.26*math.cos(a),1.30*math.sin(a),.30+(i%4)*.38))
    for f in range(1,122,4):
        phase=2*math.pi*(f-1)/120; ob.location=base+Vector((.07*math.sin(phase+i),0,.16*math.sin(phase+i)))
        ob.scale=(.6+.4*math.sin(phase+i)**2,)*3; ob.keyframe_insert(data_path='location',frame=f); ob.keyframe_insert(data_path='scale',frame=f)
scene.frame_set(1)
# Export in the source coordinate system so attachments can align with existing pig parts.
def select_asset():
    bpy.ops.object.select_all(action='DESELECT')
    for ob in parts+[rig]: ob.select_set(True)
    bpy.context.view_layer.objects.active=rig
select_asset()
common=dict(use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,apply_scale_options='FBX_SCALE_UNITS',axis_forward='-Z',axis_up='Y',use_armature_deform_only=False,use_custom_props=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True)
# Export neutral rest mesh; idle animation is a separate file.
rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=(1,0,0,0)
bpy.context.view_layer.update()
bpy.ops.export_scene.fbx(filepath=str(OUT/'Phoenix.fbx'),bake_anim=False,**common)
rig.animation_data.action=act; scene.frame_set(1)
bpy.ops.export_scene.fbx(filepath=str(OUT/'Phoenix_Idle.fbx'),bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=False,bake_anim_simplify_factor=0,bake_anim_force_startend_keying=True,**common)
bpy.ops.export_scene.gltf(filepath=str(OUT/'Phoenix.glb'),export_format='GLB',use_selection=True,export_skins=True,export_extras=True,export_animations=True)
# Rear hatch is a gameplay opening, not a decorative feather surface.
report={'source':str(Path(paths.RAW).relative_to(root.parents[1])),'source_vertex_counts':base_counts,'lowpoly_vertex_counts':lowpoly_counts,'mesh_count':len(parts),'feather_count':feather_count-2,'triangles':sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in parts),'units':'6 Roblox studs per Blender unit','axes':'Blender +Z up, -Y front. Source origin retained. Ground z=-1.02.','animation':{'name':'Phoenix_Idle','fps':30,'frames':[1,121],'duration_seconds':4},'bones':{k:{'pivot':list(p),'parent':pname} for k,(p,pname) in bones.items()},'parts':[{'name':ob.name,'bone':ob['bone'],'tone':ob['tone'],'color':RGB[ob['tone']]} for ob in parts],'fx_blender_positions':{'Crown':[.1,-.4,1.6],'Tail':[0,1.08,1.14]},'nostril_inserts':False}
(OUT/'Phoenix-report.json').write_text(json.dumps(report,indent=2))
# Neutral charcoal studio with warm rim and soft shadows.
world=bpy.data.worlds.new('Phoenix_World'); scene.world=world; world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.065,.085,1); world.node_tree.nodes['Background'].inputs[1].default_value=.45
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.025)); floor=bpy.context.object; floor.name='StudioFloor'; move_collection(floor,stage)
floorm=bpy.data.materials.new('StudioSlate'); floorm.diffuse_color=(.034,.043,.055,1); floorm.use_nodes=True; floorm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.025,.032,.045,1); floorm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88; floor.data.materials.append(floorm)
def track(ob,target): ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
for name,pos,power,size,color in [('Key',(-3,-4,6),350,4,(1,.90,.80)),('Fill',(4,-2,3),230,4,(.75,.85,1)),('Rim',(1,4,5),360,3,(1,.57,.25))]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    ob=bpy.data.objects.new(name,data); stage.objects.link(ob); ob.location=pos; track(ob,(0,0,.3))
cams={}
for name,pos,scale in [('Hero',(3.5,-6,2.55),4.5),('Rear',(-4,6,3.1),4.5),('Crown',(0,-.5,7),4.15)]:
    data=bpy.data.cameras.new(name); ob=bpy.data.objects.new(name,data); stage.objects.link(ob); ob.location=pos; track(ob,(0,0,.30)); data.type='ORTHO'; data.ortho_scale=scale; cams[name]=ob
scene.camera=cams['Hero']; scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=12; scene.cycles.use_denoising=True
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'; scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
# Blender 5.2 compositor uses a node group.
comp=bpy.data.node_groups.new('Phoenix_Glow_Compositor','CompositorNodeTree'); scene.compositing_node_group=comp
comp.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
rl=comp.nodes.new('CompositorNodeRLayers'); glare=comp.nodes.new('CompositorNodeGlare'); glare.inputs['Type'].default_value='Fog Glow'; glare.inputs['Quality'].default_value='High'; glare.inputs['Threshold'].default_value=1.5
out=comp.nodes.new('NodeGroupOutput'); comp.links.new(rl.outputs['Image'],glare.inputs['Image']); comp.links.new(glare.outputs['Image'],out.inputs['Image'])
select_asset(); scene.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=5.5; area.spaces.active.region_3d.view_location=(0,0,.3)
            area.spaces.active.region_3d.view_rotation=cams['Hero'].rotation_euler.to_quaternion(); area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=paths.skin_blend('phoenix'))
if not args.no_render:
    for name,cam in cams.items():
        scene.camera=cam; scene.render.filepath=str(OUT/('Phoenix-'+name.lower()+'.png')); bpy.ops.render.render(write_still=True)
print('PHOENIX_COMPLETE',json.dumps(report))
