"""Package an existing animal coat as a complete, UV-preserving pig asset.

Blender -b --python this_file.py -- --skin cow
Reads existing per-skin scene/maps. Never rebuilds or saves the shared master.
"""
from pathlib import Path
import sys,os,math,json,hashlib,shutil
root=Path(__file__).resolve().parent
while not (root/'paths.py').exists():root=root.parent
sys.path.insert(0,str(root))
import paths,bpy,bmesh
from mathutils import Vector
argv=sys.argv[sys.argv.index('--')+1:]
KEY=argv[argv.index('--skin')+1]
NAMES={'bee':'Bumblebee','ladybird':'Ladybird','cow':'Dairy Cow','zebra':'Zebra','giraffe':'Giraffe','leopard':'Leopard','tiger':'Bengal Tiger','snowleopard':'Snow Leopard'}
# New authored coats can reuse the same geometry/export checks without
# maintaining a second packaging implementation or altering the common list.
if '--name' in argv:NAMES[KEY]=argv[argv.index('--name')+1]
assert KEY in NAMES,'Pass --name for a newly authored coat'
OUT=Path(paths.animal_package(KEY));OUT.mkdir(exist_ok=True)
SRC=Path(paths.skin_blend(KEY))
MAPS={group:Path(paths.skin_map(KEY,group)) for group in ('body','trim')}
EMISSIVE={group:Path(paths.skin_dir(KEY))/f'{KEY}_{group}_emissive.png' for group in ('body','trim')}
EMISSIVE={group:p for group,p in EMISSIVE.items() if p.exists()}
coat_spec=Path(paths.skin_dir(KEY))/'coat-spec.json'
art=json.loads(coat_spec.read_text()) if coat_spec.exists() else {}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
inputs={str(p):sha(p) for p in [SRC,Path(paths.PARTS),*MAPS.values(),*EMISSIVE.values(),*([coat_spec] if coat_spec.exists() else [])]}
bpy.ops.wm.open_mainfile(filepath=str(SRC))
scene=bpy.context.scene
CORE=('Body','Snout','Ears','Legs','Tail')
assert all(n in bpy.data.objects for n in CORE),'Source lacks separated body parts'
KEEP=(*CORE,'EyePreview')
for obj in list(bpy.data.objects):
    if obj.name not in KEEP:bpy.data.objects.remove(obj,do_unlink=True)
for col in list(bpy.data.collections):
    if not col.objects and not col.children:bpy.data.collections.remove(col)
ASSET=bpy.data.collections.new(KEY.upper()+' • export geometry');scene.collection.children.link(ASSET)
STAGE=bpy.data.collections.new('REVIEW • cameras and lights');scene.collection.children.link(STAGE)
def move(obj,col):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    col.objects.link(obj)
def linear(rgb):
    def f(v):
        v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    return tuple(f(v) for v in rgb)
materials={};textures=[];emissive_textures=[]
for group,path in MAPS.items():
    dest=OUT/path.name
    shutil.copy2(path,dest);assert sha(dest)==inputs[str(path)]
    image=bpy.data.images.load(str(dest),check_existing=False);image.alpha_mode='CHANNEL_PACKED'
    assert tuple(image.size)==(1024,1024),f'{group}: unexpected image size {tuple(image.size)}'
    image.pack()
    material=bpy.data.materials.new(KEY+'_'+group+'_Baked');material.use_nodes=True
    nodes=material.node_tree.nodes;bsdf=nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=.88;bsdf.inputs['Specular IOR Level'].default_value=.08
    tex=nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
    material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
    if group in EMISSIVE:
        glow_dest=OUT/EMISSIVE[group].name;shutil.copy2(EMISSIVE[group],glow_dest)
        glow=bpy.data.images.load(str(glow_dest),check_existing=False);glow.colorspace_settings.name='Non-Color';glow.pack()
        mask=nodes.new('ShaderNodeTexImage');mask.image=glow
        gain=nodes.new('ShaderNodeMath');gain.operation='MULTIPLY';gain.inputs[1].default_value=art.get('emissiveStrength',.8)
        material.node_tree.links.new(mask.outputs['Color'],gain.inputs[0]);material.node_tree.links.new(gain.outputs[0],bsdf.inputs['Emission Strength'])
        material.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Emission Color'])
        emissive_textures.append({'group':group,'file':glow_dest.name,'sha256':sha(glow_dest),'strengthPreview':gain.inputs[1].default_value})
    # Common animal coats are opaque. Alpha is not a cutout channel here.
    materials[group]=material
    textures.append({'group':group,'file':dest.name,'size':list(image.size),'sha256':sha(dest)})
eye_mat=bpy.data.materials.new('Face_Eyes');eye_mat.use_nodes=True
eye_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*linear((38,30,34)),1)
eye_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.6
body=bpy.data.objects['Body'];scale=12.0/(max(v.co.x for v in body.data.vertices)-min(v.co.x for v in body.data.vertices))
objects=[];checks=[]
for name in KEEP:
    obj=bpy.data.objects.get(name)
    if obj is None:
        assert name!='EyePreview','Eyes are required for the complete preview/export'
        continue
    move(obj,ASSET);obj.hide_render=False;obj.hide_viewport=False;obj.hide_select=False;obj.hide_set(False)
    modifier_types=[m.type for m in obj.modifiers]
    assert all(t in ('SUBSURF','WEIGHTED_NORMAL','NORMAL_EDIT') for t in modifier_types),(name,modifier_types)
    for modifier in list(obj.modifiers):obj.modifiers.remove(modifier)
    original_vertices=[tuple(obj.matrix_world@v.co) for v in obj.data.vertices]
    original_uvs=[tuple(p.uv) for p in obj.data.uv_layers.active.data] if obj.data.uv_layers.active else []
    if name in CORE:assert original_uvs,name+' has no UVs'
    group='body' if name=='Body' else 'trim'
    mat=eye_mat if name=='EyePreview' else materials[group]
    # Replace existing slots in place; preserve the source ear selection.
    if not obj.data.materials:obj.data.materials.append(mat)
    for i in range(len(obj.data.materials)):obj.data.materials[i]=mat
    before_indices=[p.material_index for p in obj.data.polygons]
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    obj.scale*=scale;obj.location*=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    vertex_error=max(((obj.matrix_world@v.co)/scale-Vector(p)).length for v,p in zip(obj.data.vertices,original_vertices))
    assert vertex_error<1e-6,(name,vertex_error)
    assert before_indices==[p.material_index for p in obj.data.polygons]
    assert original_uvs==([tuple(p.uv) for p in obj.data.uv_layers.active.data] if obj.data.uv_layers.active else [])
    bm=bmesh.new();bm.from_mesh(obj.data);nonmanifold=sum(not e.is_manifold for e in bm.edges)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    assert len(obj.data.polygons)<20000,(name,'per-mesh triangle budget')
    for face in obj.data.polygons:face.use_smooth=True
    obj['sourcePart']=name;obj['textureGroup']='face' if name=='EyePreview' else group
    if name=='EyePreview':obj.name='Eyes';obj['integration']='Optional; omit if game creates eyes'
    checks.append({'name':obj.name,'sourcePart':name,'textureGroup':obj['textureGroup'],'vertices':len(obj.data.vertices),'triangles':len(obj.data.polygons),'sourceNonManifoldEdges':nonmanifold,'maxSourceVertexError':vertex_error,'uvPreservedBeforeTriangulation':True,'removedPreviewModifiers':modifier_types})
    objects.append(obj)
def bounds(obs):
    pts=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
    lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
    return {'min':lo,'max':hi,'size':[b-a for a,b in zip(lo,hi)]}
bpy.context.view_layer.update();source_bounds=bounds(objects)
assert abs(bounds([body])['size'][0]-12)<1e-5
def select(obs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
select(objects)
fbx=OUT/f'{KEY}-complete.fbx'
bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH'},global_scale=1.0,apply_unit_scale=False,bake_space_transform=True,axis_forward='-Z',axis_up='Y',use_mesh_modifiers=False,mesh_smooth_type='FACE',add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True)
# Import into this scene, check actual export, then remove only imported data.
known=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(fbx),use_anim=False)
imported=[o for o in bpy.data.objects if o not in known];meshes=[o for o in imported if o.type=='MESH']
assert len(meshes)==len(objects),(len(meshes),len(objects))
import_bounds=bounds(meshes)
error=max(abs(a-b) for key in ('min','max') for a,b in zip(source_bounds[key],import_bounds[key]))
assert error<.001,('FBX bounds drift',error)
assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==sum(r['triangles'] for r in checks)
assert all(o.data.uv_layers for o in meshes if not o.name.startswith('Eyes')),'FBX lost a coat UV map'
for o in imported:bpy.data.objects.remove(o,do_unlink=True)
report={'skin':KEY,'name':NAMES[KEY],'status':'Complete static review asset; no new coat or runtime installation','sourceScene':str(SRC.relative_to(root)),'sourceFrame':'Blender X across, -Y face, Z up; origin at body centre','bodyWidthStuds':12,'sourceToStudScale':scale,'boundsBlenderStuds':source_bounds,'fbxRoundTripMaxBoundsError':error,'meshCount':len(objects),'triangles':sum(r['triangles'] for r in checks),'parts':checks,'textures':textures,'eyes':'Optional exported Eyes mesh; game-built eyes must not be duplicated','nostrils':'Sculpted recesses retained; matching the existing coat previews, no black insert mesh','sharedGeometry':'Body, snout, ears, legs and tail are unchanged apart from uniform scale and triangulation; UVs preserved','inputHashes':inputs,'integration':'Existing skin uses shared mesh IDs plus body/trim SurfaceAppearances. Complete FBX is a standalone review/import option; do not upload duplicate base meshes for every coat.'}
report['status']='Complete static review asset; runtime installation pending'
report['rarity']=art.get('rarity','common');report['emissiveTextures']=emissive_textures
(OUT/f'{KEY}-asset-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
# Neutral studio stage for three-quarter, crown and spine inspections.
world=bpy.data.worlds.new(KEY+'_ReviewWorld');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(*linear((190,197,211)),1)
world.node_tree.nodes['Background'].inputs[1].default_value=.8
def light(name,position,energy,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);STAGE.objects.link(obj);obj.location=position
    obj.rotation_euler=(-obj.location).to_track_quat('-Z','Y').to_euler()
light('REVIEW_Key',(-20,-27,35),4500,22);light('REVIEW_Fill',(25,-10,16),3000,20);light('REVIEW_Rim',(3,22,28),5000,18)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,source_bounds['min'][2]-.02));ground=bpy.context.object;ground.name='REVIEW_Ground';move(ground,STAGE)
ground_mat=bpy.data.materials.new('ReviewGround');ground_mat.use_nodes=True;ground_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*linear((194,195,180)),1);ground_mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=1;ground.data.materials.append(ground_mat)
camera_data=bpy.data.cameras.new('REVIEW_Camera');camera=bpy.data.objects.new('REVIEW_Camera',camera_data);STAGE.objects.link(camera);scene.camera=camera;camera_data.type='ORTHO';camera_data.ortho_scale=20.0
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.view_settings.exposure=0;scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
shots=[('hero',(-23,-31,16),(0,0,0)),('front',(0,-37,9),(0,0,1)),('crown',(-8,-21,30),(0,0,2)),('spine',(2,24,30),(0,1,2))]
for name,position,target in shots:
    camera.location=position;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'{KEY}-{name}.png');bpy.ops.render.render(write_still=True)
camera.location=shots[0][1];camera.rotation_euler=(Vector(shots[0][2])-camera.location).to_track_quat('-Z','Y').to_euler()
if emissive_textures:
    world.node_tree.nodes['Background'].inputs[1].default_value=.10
    lamps=[ob.data for ob in STAGE.objects if ob.type=='LIGHT']
    for lamp in lamps:lamp.energy*=.12
    scene.render.filepath=str(OUT/f'{KEY}-glow.png');bpy.ops.render.render(write_still=True)
    for lamp in lamps:lamp.energy/=.12
    world.node_tree.nodes['Background'].inputs[1].default_value=.8
select(objects);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{KEY}-complete.blend'))
assert all(sha(p)==digest for p,digest in inputs.items()),'Source scene, master or coat changed while packaging'
print('ANIMAL_PACKAGE',json.dumps({'skin':KEY,'meshes':len(objects),'triangles':report['triangles'],'fbxBoundsError':error,'sourceFilesUnchanged':True}),flush=True)
