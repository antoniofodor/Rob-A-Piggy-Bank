"""Revise the existing Storm Wolf for the shared piggy bank fixtures.

Never rewrites its source scene, painted sheet, bolt source, or common master.
Blender -b --python make/build_stormwolf_layout.py -- [--draft]
"""
from pathlib import Path
import bpy,bmesh,math,json,hashlib,sys,shutil
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
import sys as _sys;_sys.path.insert(0,str(ROOT));import paths
OUT=Path(paths.animal_package('stormwolf'))
SOURCE=Path(paths.skin_blend('stormwolf'))
SHEET=Path(paths.skin_map('stormwolf','body'))
BOLTS=ROOT/'pig/pig_stormwolf_bolts.blend'
INPUTS={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE,SHEET,BOLTS,ROOT/'pig/pig_parts.blend')}
DRAFT='--draft' in sys.argv
SCALE=6.0
# Shared bore axis/radius; keep a deposit anchor under the continuous mane.
N=Vector((0,math.sqrt(36-1.9**2),-1.9)).normalized()
HATCH_T=1/math.sqrt((N.y/1.08)**2+(N.z/.96)**2)
HATCH=N*HATCH_T;RADIUS=1.43/SCALE
SLOT_W=.7/SCALE;SLOT_L=4.2*.75/SCALE

def select(ob):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob

def apply(ob):
    select(ob);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)

def material(name,color,metal=0,emission=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=.72;b.inputs['Metallic'].default_value=metal
    b.inputs['Emission Color'].default_value=(*color,1);b.inputs['Emission Strength'].default_value=emission
    return m

def boolean(ob,cut,op='DIFFERENCE'):
    select(ob);m=ob.modifiers.new('FixtureCut','BOOLEAN');m.operation=op;m.solver='EXACT';m.object=cut
    bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cut,do_unlink=True)

def cylinder(name,radius,start,end):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=radius,depth=end-start)
    ob=bpy.context.object;ob.name=name;ob.location=N*((start+end)/2);ob.rotation_euler=N.to_track_quat('Z','Y').to_euler();apply(ob)
    return ob

def tree(ob):
    bm=bmesh.new();bm.from_mesh(ob.data);bm.transform(ob.matrix_world);result=BVHTree.FromBMesh(bm);bm.free();return result

TAIL_ROOT=N*.94
TAIL_MOUNT=Vector((0,.91,.08))
TAIL_ROT=Matrix.Rotation(math.radians(20),3,'X')
def lift_tail(co):
    co[:]=TAIL_MOUNT+TAIL_ROT@(co-TAIL_ROOT)

def tail_box():
    bpy.ops.mesh.primitive_cube_add(size=1,location=N*2.94)
    cut=bpy.context.object;cut.scale=(6,6,4);cut.rotation_euler=N.to_track_quat('Z','Y').to_euler();apply(cut)
    cut.data.materials.append(coat);cut.data.materials.append(inside);cut.data.materials.append(seam)
    for p in cut.data.polygons:p.material_index=2
    return cut

bpy.ops.wm.open_mainfile(filepath=str(SOURCE));body=bpy.data.objects['Body'];apply(body)
for ob in list(bpy.data.objects):
    if ob!=body:bpy.data.objects.remove(ob,do_unlink=True)
original_uv={tuple(round(c,7) for c in v.co):[] for v in body.data.vertices}
uv=body.data.uv_layers.active
for loop in body.data.loops:original_uv[tuple(round(c,7) for c in body.data.vertices[loop.vertex_index].co)].append(tuple(uv.data[loop.index].uv))
original_uv_rounded={tuple(round(c,5) for c in key):values for key,values in original_uv.items()}
coat=material('StormWolf_OriginalCoat',(.02,.03,.05))
image=bpy.data.images.load(str(SHEET));image.pack();tex=coat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
coat.node_tree.links.new(tex.outputs['Color'],coat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
inside=material('StormWolf_InnerShell',(.035,.055,.080));seam=material('StormWolf_ClosedTailRoot',(.012,.020,.034))
body.data.materials.clear();body.data.materials.append(coat);body.data.materials.append(inside);body.data.materials.append(seam)
sys.path.insert(0,str(Path(__file__).parent))
import stormwolf_body_glow
glow_report=stormwolf_body_glow.attach(body,coat,tex,OUT)
bm=bmesh.new();bm.from_mesh(body.data)
boundary=[e for e in bm.edges if e.is_boundary]
assert len(boundary)==4,('Unexpected source boundary',len(boundary))
holeverts=list({v for e in boundary for v in e.verts})
assert max((v.co-holeverts[0].co).length for v in holeverts)<.01
bmesh.ops.pointmerge(bm,verts=holeverts,merge_co=sum((v.co for v in holeverts),Vector())/len(holeverts))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
# Separate at the narrow root and reposition rigidly: preserve the original
# tail shape and texture instead of stretching a fused mesh across the dial.
tail=body.copy();tail.data=body.data.copy();tail.name='Tail';bpy.context.scene.collection.objects.link(tail)
boolean(tail,tail_box(),'INTERSECT')
bm=bmesh.new();bm.from_mesh(tail.data);pending=set(bm.verts);tail_components=[]
while pending:
    queue=[pending.pop()];component=[]
    while queue:
        v=queue.pop();component.append(v)
        for e in v.link_edges:
            w=e.other_vert(v)
            if w in pending:pending.remove(w);queue.append(w)
    center=sum((v.co for v in component),Vector())/len(component)
    tail_components.append(dict(vertices=len(component),center=list(center)))
    if center.z>.12:bmesh.ops.delete(bm,geom=component,context='VERTS')
print('TAIL_COMPONENTS',json.dumps(tail_components),flush=True)
bm.to_mesh(tail.data);bm.free()
cut=tail.copy();cut.data=tail.data.copy();bpy.context.scene.collection.objects.link(cut);boolean(body,cut)
# Locate the actual cut root and aim the existing tuft along the rear centre
# line before lifting it. The imported tail bends left in its source frame.
root_vertices=[v.co for v in tail.data.vertices if abs(v.co.dot(N)-.94)<1e-4]
TAIL_ROOT=sum(root_vertices,Vector())/len(root_vertices)
tip_vertices=[v.co for v in tail.data.vertices if v.co.dot(N)>1.20]
tip_center=sum(tip_vertices,Vector())/len(tip_vertices)
direction=tip_center-TAIL_ROOT
TAIL_ROT=Matrix.Rotation(math.radians(5),3,'X')@Matrix.Rotation(math.atan2(direction.x,direction.y),3,'Z')
for v in tail.data.vertices:lift_tail(v.co)

# Carve a real internal chamber, with a separate dark interior material.
bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,location=(0,0,-.02))
cavity=bpy.context.object;cavity.scale=(.72,.74,.66);apply(cavity)
cavity.data.materials.append(coat);cavity.data.materials.append(inside)
for p in cavity.data.polygons:p.material_index=1
boolean(body,cavity)
cut=cylinder('VaultBore',RADIUS,.48,2.5);cut.data.materials.append(coat);cut.data.materials.append(inside)
for p in cut.data.polygons:p.material_index=1
boolean(body,cut)
# User revision: leave the mane continuous over the deposit location. No
# visible coin slit or rim is wanted on this skin; retain only its anchor.

# The hatch is a flush cut through the painted hide. No exterior neck or ring.

with bpy.data.libraries.load(str(BOLTS)) as (src,dst):dst.objects=['Bolts_eyes']
eyes=dst.objects[0];bpy.context.scene.collection.objects.link(eyes);apply(eyes)
eyes.data.materials.clear();eyes.data.materials.append(material('StormWolf_Eyes',(.12,.65,.85),emission=.8))
sys.path.insert(0,str(Path(__file__).parent))
import stormwolf_lightning
bolts,lightning_spec=stormwolf_lightning.build(tree(body),tail,OUT)
bolts.append(eyes)
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=60;scene.render.fps=30;scene.frame_set(11)
objects=[body,tail]+bolts
# Subtractive edits must never add a cutter-shaped protrusion. A manifold
# result alone cannot detect an inverted Boolean volume.
source_bounds=[(min(co[i] for co in original_uv),max(co[i] for co in original_uv)) for i in range(3)]
assert all(lo-1e-5<=v.co[i]<=hi+1e-5 for v in body.data.vertices for i,(lo,hi) in enumerate(source_bounds)),'Body escaped its original envelope'

# Check the full hatch disk and the maximum dial plate clearance.
trees=[tree(ob) for ob in objects];U=Vector((1,0,0));V=N.cross(U).normalized()
blocked=[]
for i in range(72):
    for fraction in (.0,.35,.60,.80,.95):
        offset=(U*math.cos(i*math.tau/72)+V*math.sin(i*math.tau/72))*RADIUS*fraction
        origin=HATCH+offset+N*.70
        for ob,t in zip(objects,trees):
            hit=t.ray_cast(origin,-N,1.22)
            if hit[0] is not None:blocked.append((ob.name,i,fraction))
slot_status='Covered by continuous mane, no visible slit or rim, as requested. Deposit anchor retained.'
plate_blocked=[]
for i in range(72):
    for fraction in (.35,.65,.85,1.0):
        offset=(U*math.cos(i*math.tau/72)+V*math.sin(i*math.tau/72))*(1.95/SCALE)*fraction
        for ob,t in zip(objects,trees):
            if t.ray_cast(HATCH+offset+N*.50,-N,.475)[0] is not None:plate_blocked.append((ob.name,i,fraction))
uv_checks=[]
for ob in (body,tail):
    count=0;error=0.0;layer=ob.data.uv_layers.active
    for p in ob.data.polygons:
        if p.material_index!=0:continue
        for li in p.loop_indices:
            co=ob.data.vertices[ob.data.loops[li].vertex_index].co.copy()
            if ob==tail:co=TAIL_ROOT+TAIL_ROT.inverted()@(co-TAIL_MOUNT)
            # Boolean-created vertices interpolate their UVs; compare retained
            # source vertices directly, allowing coordinate float roundoff.
            key=tuple(round(c,5) for c in co)
            if key in original_uv_rounded:
                count+=1;actual=layer.data[li].uv
                error=max(error,min((actual-Vector(expected)).length for expected in original_uv_rounded[key]))
    uv_checks.append(dict(name=ob.name,retainedSourceLoopsChecked=count,maxUVError=error))
assert all(r['retainedSourceLoopsChecked']>500 and r['maxUVError']<1e-5 for r in uv_checks),uv_checks
meshchecks=[]
for ob in (body,tail):
    bm=bmesh.new();bm.from_mesh(ob.data)
    if any(not e.is_manifold for e in bm.edges):
        print('OPEN_EDGES',[(tuple(e.verts[0].co),tuple(e.verts[1].co),len(e.link_faces)) for e in bm.edges if not e.is_manifold],flush=True)
    meshchecks.append(dict(name=ob.name,triangles=sum(len(p.vertices)-2 for p in ob.data.polygons),nonManifoldEdges=sum(not e.is_manifold for e in bm.edges)))
    bm.free()
print('LAYOUT_CHECKS',json.dumps(dict(vaultBlocked=blocked,coinSlot=slot_status,plateBlocked=plate_blocked,meshes=meshchecks,uv=uv_checks)),flush=True)
report=dict(inputHashes=INPUTS,source='Existing painted Storm Wolf and original UVs; chunky branching lightning and masked body glow',bodyGlow=glow_report,
    layout=dict(scaleToStuds=SCALE,vaultCenterBlender=list(HATCH),vaultNormalBlender=list(N),vaultRadiusStuds=1.43,coinSlotStuds=[.7,3.15]),
    vaultBlocked=blocked,coinSlot=slot_status,plateBlocked=plate_blocked,meshes=meshchecks,uv=uv_checks,lightning=lightning_spec,
    tailMountBlender=list(TAIL_MOUNT),tailLiftDegrees=5,
    changes=['Closed the original four-edge mesh pinhole','Hollow interior chamber','Flush rear vault opening, no exterior collar','Continuous mane conceals the coin deposit location; no visible slot','Original tail centred just above the opening and projecting rearward','Removed all six original bolt meshes; eight longer branching bolts in six rapid flicker groups'])
(OUT/'stormwolf-layout-checks.json').write_text(json.dumps(report,indent=2))

# Save an editable source in native coordinates before preparing review views.
bpy.context.preferences.filepaths.save_version=0
select(body);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'stormwolf-layout.blend'))
assert not blocked,('Vault blocked',blocked[:10])
assert not plate_blocked,('Vault plate clearance',plate_blocked[:10])
assert all(m['nonManifoldEdges']==0 for m in meshchecks),meshchecks
assert all(m['triangles']<21000 for m in meshchecks),meshchecks

world=bpy.data.worlds.new('StormWolf_ReviewWorld');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.5,.6,.7,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7
for name,position,power,size in [('Key',(-3,-4,5),450,4),('Fill',(4,-2,3),350,3),('Rim',(2,4,4),500,3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=position;ob.rotation_euler=(-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.03));ground=bpy.context.object;ground.name='REVIEW_Ground';ground.data.materials.append(material('ReviewGround',(.35,.37,.34)))
camera=bpy.data.objects.new('REVIEW_Camera',bpy.data.cameras.new('REVIEW_Camera'));scene.collection.objects.link(camera);scene.camera=camera
camera.data.type='ORTHO';camera.data.ortho_scale=4.5
scene.render.engine='CYCLES';scene.cycles.samples=8 if DRAFT else 24;scene.cycles.use_denoising=True
scene.render.resolution_x=700 if DRAFT else 1000;scene.render.resolution_y=scene.render.resolution_x;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard';scene.render.image_settings.file_format='PNG'
stormwolf_lightning.compositor(scene)
shots=[('hero',(-3.3,-4.5,2),(0,0,.1)),('rear',(0,5,1.2),(0,.2,0)),('crown',(-1.5,1.3,5),(0,0,.15))]
if not DRAFT:shots.extend([('front',(0,-5,1),(0,0,.1)),('side',(4,3,1.7),(0,.3,0)),('vault',tuple(HATCH+N*1.7),tuple(HATCH))])
for name,position,target in shots:
    ground.hide_render=name=='vault';camera.data.ortho_scale=1.35 if name=='vault' else 4.5
    camera.location=position;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'stormwolf-{name}.png');bpy.ops.render.render(write_still=True)
ground.hide_render=False;camera.data.ortho_scale=4.5
camera.location=shots[0][1];camera.rotation_euler=(Vector(shots[0][2])-camera.location).to_track_quat('-Z','Y').to_euler()
if not DRAFT:
    for name,location,normal in [('VaultMount',HATCH,N),('CoinSlotMount',Vector((0,SLOT_L/2,1.18)),Vector((0,0,1)))]:
        anchor=bpy.data.objects.new(name,None);scene.collection.objects.link(anchor);anchor.location=location
        anchor.rotation_euler=normal.to_track_quat('Z','Y').to_euler();anchor.empty_display_size=.12
        anchor['purpose']='Reference mount only; functional parts are built by the game'
    # Deliver the complete Blender scene and FBX in the same stud scale as the
    # common/rare packages. The native editable scene above stays at scale 1.
    for ob in list(scene.objects):
        ob.location*=SCALE
        if ob.type=='MESH':
            ob.scale*=SCALE;select(ob);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        elif ob.type=='LIGHT':ob.data.energy*=SCALE*SCALE;ob.data.size*=SCALE
        elif ob.type=='CAMERA':ob.data.ortho_scale*=SCALE
        elif ob.type=='EMPTY':ob.empty_display_size*=SCALE
    shutil.copy2(SHEET,OUT/SHEET.name)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=body
    fbx=OUT/'stormwolf-complete.fbx'
    bpy.ops.export_scene.fbx(filepath=str(fbx),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',
        add_leaf_bones=False,bake_anim=False,path_mode='COPY',embed_textures=True,use_triangles=True)
    def bounds(obs):
        points=[o.matrix_world@v.co for o in obs for v in o.data.vertices]
        return {key:[fn(c[i] for c in points) for i in range(3)] for key,fn in [('min',min),('max',max)]}
    before=bounds(objects);known=set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(fbx),use_anim=False)
    imported=[o for o in bpy.data.objects if o not in known];meshes=[o for o in imported if o.type=='MESH']
    after=bounds(meshes);drift=max(abs(a-b) for key in before for a,b in zip(before[key],after[key]))
    assert len(meshes)==len(objects) and drift<1e-4,(len(meshes),len(objects),drift)
    total=sum(len(p.vertices)-2 for o in objects for p in o.data.polygons)
    assert sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons)==total
    assert all(o.data.uv_layers for o in meshes if o.name.startswith(('Body','Tail')))
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)
    report.update(meshCount=len(objects),totalTriangles=total,fbxRoundTripBoundsError=drift,boundsStuds=before,
        animation='Six new lightning groups, stepped visibility and emission, 60-frame Blender preview; Studio helper included separately. FBX geometry is static.')
    (OUT/'stormwolf-layout-checks.json').write_text(json.dumps(report,indent=2))
    select(body);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'stormwolf-complete.blend'))
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==digest for p,digest in INPUTS.items())
print('STORMWOLF_LAYOUT_REVIEW_READY',flush=True)
